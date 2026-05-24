import pandas as pd

from sqlalchemy import create_engine

from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor

from sklearn.metrics import mean_absolute_error
from sklearn.metrics import root_mean_squared_error

DATABASE_URL = (
    "postgresql+psycopg2://postgres:postgres@postgres:5432/oil_data"
)

engine = create_engine(DATABASE_URL)

df = pd.read_sql("select * from ml_dataset", engine)

features = [
    "avg_pressure",
    "avg_temperature",
    "avg_power",
    "avg_pump_hours"
]

target = "target_oil_tons"

X = df[features]
y = df[target]

X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.2,
    random_state=42
)

lr_model = LinearRegression()

lr_model.fit(X_train, y_train)

lr_predictions = lr_model.predict(X_test)

lr_mae = mean_absolute_error(y_test, lr_predictions)

lr_rmse = root_mean_squared_error(y_test, lr_predictions)

print("\nLinear Regression")
print(f"MAE: {lr_mae:.2f}")
print(f"RMSE: {lr_rmse:.2f}")

rf_model = RandomForestRegressor(
    n_estimators=100,
    random_state=42
)

rf_model.fit(X_train, y_train)

rf_predictions = rf_model.predict(X_test)

rf_mae = mean_absolute_error(y_test, rf_predictions)

rf_rmse = root_mean_squared_error(y_test, rf_predictions)

print("\nRandom Forest")
print(f"MAE: {rf_mae:.2f}")
print(f"RMSE: {rf_rmse:.2f}")

predictions_df = df.loc[X_test.index, [
    "well_id",
    "production_date",
    "avg_pressure",
    "avg_temperature",
    "avg_power",
    "avg_pump_hours"
]].copy()

predictions_df["actual"] = y_test.values
predictions_df["predicted"] = rf_predictions
predictions_df["error"] = (
    predictions_df["actual"] -
    predictions_df["predicted"]
).abs()

predictions_df.to_sql(
    "ml_predictions",
    engine,
    if_exists="replace",
    index=False
)

metrics_df = pd.DataFrame({
    "model_name": ["LinearRegression", "RandomForest"],
    "mae": [lr_mae, rf_mae],
    "rmse": [lr_rmse, rf_rmse]
})

metrics_df.to_sql(
    "ml_metrics",
    engine,
    if_exists="replace",
    index=False
)

print("\nPredictions saved")
print("Metrics saved")