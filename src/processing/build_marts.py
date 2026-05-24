import pandas as pd
from sqlalchemy import create_engine, text

POSTGRES_URL = "postgresql+psycopg2://postgres:postgres@postgres:5432/oil_data"


def save_mart(df, table_name, engine):
    df.to_sql(table_name, engine, if_exists="replace", index=False)
    print(f"{table_name}: {len(df)} rows saved")


def build_marts():
    engine = create_engine(POSTGRES_URL)

    production = pd.read_sql("select * from production", engine)
    telemetry = pd.read_sql("select * from telemetry", engine)
    wells = pd.read_sql("select * from wells", engine)
    failures = pd.read_sql("select * from pump_failures", engine)
    sensors = pd.read_sql("select * from pump_sensors", engine)
    deliveries = pd.read_sql("select * from deliveries", engine)
    targets = pd.read_sql("select * from well_targets", engine)

    production = production.rename(columns={"production_date": "date"})
    telemetry = telemetry.rename(columns={
        "sensor_ts": "timestamp",
        "pressure_atm": "pressure",
        "temperature_c": "temperature",
        "energy_kwh": "energy_consumption",
    })
    sensors = sensors.rename(columns={
        "sensor_ts": "timestamp",
        "vibration_mm_s": "vibration",
        "temperature_c": "temperature",
        "current_a": "current",
    })
    failures = failures.rename(columns={"failure_ts": "failure_date"})
    targets = targets.rename(columns={"target_date": "date"})

    production["date"] = pd.to_datetime(production["date"]).dt.date
    telemetry["timestamp"] = pd.to_datetime(telemetry["timestamp"])
    telemetry["date"] = telemetry["timestamp"].dt.date
    sensors["timestamp"] = pd.to_datetime(sensors["timestamp"])
    sensors["date"] = sensors["timestamp"].dt.date
    targets["date"] = pd.to_datetime(targets["date"]).dt.date

    telemetry_daily = (
        telemetry.groupby(["date", "well_id"], as_index=False)
        .agg(
            avg_pressure=("pressure", "mean"),
            avg_temperature=("temperature", "mean"),
            avg_energy=("energy_consumption", "mean"),
            avg_power_kw=("pump_power_kw", "mean"),
            avg_runtime_hours=("pump_runtime_hours", "mean"),
        )
    )

    mart_production = (
        production
        .merge(wells, on="well_id", how="left")
        .merge(telemetry_daily, on=["date", "well_id"], how="left")
    )

    mart_production["downtime_pct"] = (
        mart_production["downtime_hours"] / 24 * 100
    ).round(2)

    sensor_daily = (
        sensors.groupby(["date", "pump_id", "well_id"], as_index=False)
        .agg(
            avg_vibration=("vibration", "mean"),
            avg_temperature=("temperature", "mean"),
            avg_current=("current", "mean"),
            avg_rpm=("rpm", "mean"),
        )
    )

    mart_failures = sensor_daily.merge(
        failures,
        on=["pump_id", "well_id"],
        how="left",
    )

    mart_failures["failure_date"] = pd.to_datetime(
        mart_failures["failure_date"],
        errors="coerce",
    )

    mart_failures["date"] = pd.to_datetime(mart_failures["date"])

    mart_failures["days_before_failure"] = (
        mart_failures["failure_date"] - mart_failures["date"]
    ).dt.days

    mart_failures["failure_window_7d"] = (
        mart_failures["days_before_failure"].between(0, 7)
    )

    mart_failures["has_failure"] = mart_failures["failure_date"].notna()

    mart_logistics = deliveries.copy()

    if "delivery_date" in mart_logistics.columns:
        mart_logistics["delivery_date"] = pd.to_datetime(mart_logistics["delivery_date"])

    if {"cost", "distance_km"}.issubset(mart_logistics.columns):
        mart_logistics["cost_per_km"] = (
            mart_logistics["cost"] / mart_logistics["distance_km"]
        ).round(2)

    if "delay_hours" in mart_logistics.columns:
        mart_logistics["delay_flag"] = mart_logistics["delay_hours"] > 0

    mart_ml_dataset = (
        targets
        .merge(wells, on="well_id", how="left")
    )

    save_mart(mart_production, "mart_production", engine)
    save_mart(mart_failures, "mart_failures", engine)
    save_mart(mart_logistics, "mart_logistics", engine)
    save_mart(mart_ml_dataset, "mart_ml_dataset", engine)

    with engine.begin() as conn:
        for table in [
            "mart_production",
            "mart_failures",
            "mart_logistics",
            "mart_ml_dataset",
        ]:
            count = conn.execute(text(f"select count(*) from {table}")).scalar()
            print(f"{table}: {count} rows in PostgreSQL")


if __name__ == "__main__":
    build_marts()