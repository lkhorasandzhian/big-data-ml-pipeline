import pandas as pd
from sqlalchemy import create_engine

DATABASE_URL = (
    "postgresql+psycopg2://postgres:postgres@postgres:5432/oil_data"
)

engine = create_engine(DATABASE_URL)

query = """
select
    wt.well_id,
    wt.target_date as production_date,

    wt.avg_pressure_atm as avg_pressure,
    wt.avg_temperature_c as avg_temperature,
    wt.avg_power_kw as avg_power,
    wt.pump_runtime_hours as avg_pump_hours,

    wt.target_oil_tons

from well_targets wt

order by wt.target_date
"""

df = pd.read_sql(query, engine)

print(df.head())
print(df.shape)

df.to_sql(
    "ml_dataset",
    engine,
    if_exists="replace",
    index=False
)

print("ml_dataset saved")