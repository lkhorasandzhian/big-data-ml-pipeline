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
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "raw")

TABLES = {
    "wells": None,
    "production": "production_date",
    "telemetry": "sensor_ts",
    "well_targets": "target_date",
    "pump_sensors": "sensor_ts",
    "pump_failures": "failure_ts",
    "deliveries": "delivery_date",
}


def get_postgres_engine():
    return create_engine(POSTGRES_URL)


def get_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
    )


def upload_parquet_to_minio(s3, df: pd.DataFrame, table: str, object_key: str):
    buffer = BytesIO()
    df.to_parquet(buffer, index=False)
    buffer.seek(0)

    s3.put_object(
        Bucket=MINIO_BUCKET,
        Key=object_key,
        Body=buffer.getvalue(),
        ContentType="application/octet-stream",
    )

    print(f"Uploaded: s3://{MINIO_BUCKET}/{object_key} rows={len(df)}")


def export_table(engine, s3, table: str, date_column: str | None):
    df = pd.read_sql(f"SELECT * FROM {table}", engine)

    if df.empty:
        print(f"Skipped empty table: {table}")
        return

    if date_column is None:
        object_key = f"{table}/{table}.parquet"
        upload_parquet_to_minio(s3, df, table, object_key)
        return

    df[date_column] = pd.to_datetime(df[date_column])
    df["year"] = df[date_column].dt.year
    df["month"] = df[date_column].dt.month
    df["day"] = df[date_column].dt.day

    for (year, month, day), part_df in df.groupby(["year", "month", "day"]):
        part_df = part_df.drop(columns=["year", "month", "day"])
        object_key = (
            f"{table}/year={year}/month={month:02d}/day={day:02d}/"
            f"{table}.parquet"
        )
        upload_parquet_to_minio(s3, part_df, table, object_key)


def main():
    engine = get_postgres_engine()
    s3 = get_s3_client()

    for table, date_column in TABLES.items():
        print(f"Exporting table: {table}")
        export_table(engine, s3, table, date_column)

    print("ETL export completed successfully.")


if __name__ == "__main__":
    main()