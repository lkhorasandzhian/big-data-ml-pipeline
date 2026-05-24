import os
from io import BytesIO

import boto3
import pandas as pd
from sqlalchemy import create_engine


POSTGRES_URL = os.getenv(
    "POSTGRES_URL",
    "postgresql+psycopg2://postgres:postgres@postgres:5432/oil_data",
)

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://minio:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ROOT_USER", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_ROOT_PASSWORD", "minioadmin")
MINIO_BUCKET = os.getenv("MINIO_PROCESSED_BUCKET", "processed")


def clip_outliers_iqr(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    df = df.copy()

    for col in columns:
        if col not in df.columns:
            continue

        q1 = df[col].quantile(0.25)
        q3 = df[col].quantile(0.75)
        iqr = q3 - q1

        lower = q1 - 1.5 * iqr
        upper = q3 + 1.5 * iqr

        df = df[df[col].between(lower, upper) | df[col].isna()]

    return df


def save_parquet_to_minio(df: pd.DataFrame, object_name: str) -> None:
    buffer = BytesIO()
    df.to_parquet(buffer, index=False)
    buffer.seek(0)

    client = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
    )

    buckets = [bucket["Name"] for bucket in client.list_buckets()["Buckets"]]
    if MINIO_BUCKET not in buckets:
        client.create_bucket(Bucket=MINIO_BUCKET)

    client.put_object(
        Bucket=MINIO_BUCKET,
        Key=object_name,
        Body=buffer.getvalue(),
    )


def main() -> None:
    engine = create_engine(POSTGRES_URL)

    production = pd.read_sql("select * from production", engine)
    telemetry = pd.read_sql("select * from telemetry", engine)
    wells = pd.read_sql("select * from wells", engine)

    production["production_date"] = pd.to_datetime(production["production_date"])
    telemetry["sensor_ts"] = pd.to_datetime(telemetry["sensor_ts"])
    telemetry["production_date"] = telemetry["sensor_ts"].dt.date
    telemetry["production_date"] = pd.to_datetime(telemetry["production_date"])

    numeric_production_cols = [
        "oil_tons",
        "water_tons",
        "gas_m3",
        "downtime_hours",
    ]

    numeric_telemetry_cols = [
        "pressure_atm",
        "temperature_c",
        "pump_power_kw",
        "pump_runtime_hours",
    ]

    for col in numeric_production_cols:
        if col in production.columns:
            production[col] = production[col].fillna(production[col].median())

    for col in numeric_telemetry_cols:
        if col in telemetry.columns:
            telemetry[col] = telemetry[col].fillna(telemetry[col].median())

    production = clip_outliers_iqr(production, numeric_production_cols)
    telemetry = clip_outliers_iqr(telemetry, numeric_telemetry_cols)

    telemetry_daily = (
        telemetry
        .groupby(["well_id", "production_date"], as_index=False)
        .agg(
            avg_pressure=("pressure_atm", "mean"),
            avg_temperature=("temperature_c", "mean"),
            avg_power_kw=("pump_power_kw", "mean"),
            avg_pump_runtime_hours=("pump_runtime_hours", "mean"),
        )
    )

    production_daily = (
        production
        .groupby(["well_id", "production_date"], as_index=False)
        .agg(
            daily_oil_tons=("oil_tons", "sum"),
            daily_water_tons=("water_tons", "sum"),
            daily_gas_m3=("gas_m3", "sum"),
            downtime_hours=("downtime_hours", "sum"),
        )
    )

    features_daily = production_daily.merge(
        telemetry_daily,
        on=["well_id", "production_date"],
        how="left",
    )

    features_daily["downtime_ratio"] = (
        features_daily["downtime_hours"] / 24
    ).clip(0, 1)

    features_daily = features_daily.merge(wells, on="well_id", how="left")

    features_by_well = (
        features_daily
        .groupby("well_id", as_index=False)
        .agg(
            avg_daily_oil_tons=("daily_oil_tons", "mean"),
            total_oil_tons=("daily_oil_tons", "sum"),
            avg_pressure=("avg_pressure", "mean"),
            avg_temperature=("avg_temperature", "mean"),
            downtime_ratio=("downtime_ratio", "mean"),
        )
    )

    save_parquet_to_minio(features_daily, "features/features_daily.parquet")
    save_parquet_to_minio(features_by_well, "features/features_by_well.parquet")

    features_daily.to_parquet("/tmp/features_daily.parquet", index=False)
    features_by_well.to_parquet("/tmp/features_by_well.parquet", index=False)

    print("Feature engineering completed")
    print(f"features_daily rows: {len(features_daily)}")
    print(f"features_by_well rows: {len(features_by_well)}")


if __name__ == "__main__":
    main()