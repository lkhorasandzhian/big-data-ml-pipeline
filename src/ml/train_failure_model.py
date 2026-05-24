import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score, accuracy_score
from sqlalchemy import create_engine


FEATURES = ["vibration", "temperature", "current_amp", "rpm"]

COLUMN_RENAME_MAP = {
    "sensor_ts": "sensor_datetime",
    "vibration_mm_s": "vibration",
    "temperature_c": "temperature",
    "current_a": "current_amp",
}


def main():
    engine = create_engine("postgresql+psycopg2://postgres:postgres@postgres:5432/oil_data")

    sensors = pd.read_sql("select * from pump_sensors", engine)
    failures = pd.read_sql("select * from pump_failures", engine)

    sensors = sensors.rename(columns=COLUMN_RENAME_MAP)
    failures = failures.rename(columns={
        "failure_ts": "failure_date"
    })

    sensors["sensor_datetime"] = pd.to_datetime(sensors["sensor_datetime"])
    sensors["sensor_date"] = sensors["sensor_datetime"].dt.date

    failures["failure_date"] = pd.to_datetime(failures["failure_date"]).dt.date

    sensors = sensors.sort_values(["pump_id", "sensor_datetime"])

    scaler = StandardScaler()
    z_values = scaler.fit_transform(sensors[FEATURES])

    for i, col in enumerate(FEATURES):
        sensors[f"{col}_zscore"] = z_values[:, i]

    sensors["zscore_max"] = sensors[[f"{c}_zscore" for c in FEATURES]].abs().max(axis=1)
    sensors["is_zscore_anomaly"] = sensors["zscore_max"] > 3

    iso = IsolationForest(
        n_estimators=200,
        contamination=0.05,
        random_state=42
    )

    sensors["isolation_label"] = iso.fit_predict(sensors[FEATURES])
    sensors["is_isolation_anomaly"] = sensors["isolation_label"] == -1
    sensors["isolation_score"] = -iso.decision_function(sensors[FEATURES])

    failure_rows = []

    for _, failure in failures.iterrows():
        pump_id = failure["pump_id"]
        failure_date = failure["failure_date"]
        failure_start_date = failure_date - pd.Timedelta(days=7).to_pytimedelta()

        mask = (
            (sensors["pump_id"] == pump_id)
            & (sensors["sensor_date"] <= failure_date)
            & (sensors["sensor_date"] >= failure_start_date)
        )

        failure_rows.append(sensors.loc[mask].index)

    pre_failure_idx = (
        pd.Index(np.concatenate([idx.values for idx in failure_rows]))
        if failure_rows
        else pd.Index([])
    )

    sensors["failure_next_7d"] = sensors.index.isin(pre_failure_idx).astype(int)

    for col in FEATURES:
        sensors[f"{col}_rolling_mean_24h"] = (
            sensors.groupby("pump_id")[col]
            .transform(lambda x: x.rolling(24, min_periods=1).mean())
        )

    model_features = FEATURES + [f"{c}_rolling_mean_24h" for c in FEATURES] + [
        "zscore_max",
        "isolation_score",
    ]

    X = sensors[model_features].fillna(0)
    y = sensors["failure_next_7d"]

    if y.nunique() > 1:
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.25, random_state=42, stratify=y
        )

        clf = RandomForestClassifier(
            n_estimators=200,
            max_depth=6,
            random_state=42,
            class_weight="balanced"
        )

        clf.fit(X_train, y_train)

        sensors["failure_probability"] = clf.predict_proba(X)[:, 1]

        y_pred = clf.predict(X_test)
        y_proba = clf.predict_proba(X_test)[:, 1]

        metrics = pd.DataFrame([{
            "model_name": "RandomForest failure risk",
            "accuracy": accuracy_score(y_test, y_pred),
            "roc_auc": roc_auc_score(y_test, y_proba),
            "rows_count": len(sensors),
            "positive_rows": int(y.sum()),
        }])
    else:
        sensors["failure_probability"] = sensors["isolation_score"]
        sensors["failure_probability"] = (
            sensors["failure_probability"] - sensors["failure_probability"].min()
        ) / (
            sensors["failure_probability"].max() - sensors["failure_probability"].min()
        )

        metrics = pd.DataFrame([{
            "model_name": "Isolation fallback failure risk",
            "accuracy": None,
            "roc_auc": None,
            "rows_count": len(sensors),
            "positive_rows": int(y.sum()),
        }])

    sensors["risk_score"] = (
        0.4 * sensors["failure_probability"]
        + 0.3 * sensors["is_isolation_anomaly"].astype(int)
        + 0.3 * (sensors["zscore_max"] / sensors["zscore_max"].max())
    ).clip(0, 1)

    anomaly_results = sensors[[
        "pump_id",
        "well_id",
        "sensor_datetime",
        "sensor_date",
        *FEATURES,
        "zscore_max",
        "is_zscore_anomaly",
        "is_isolation_anomaly",
        "isolation_score",
        "failure_next_7d",
        "failure_probability",
        "risk_score",
    ]]

    pump_risk_daily = (
        anomaly_results
        .groupby(["sensor_date", "pump_id", "well_id"], as_index=False)
        .agg(
            avg_vibration=("vibration", "mean"),
            avg_temperature=("temperature", "mean"),
            avg_current_amp=("current_amp", "mean"),
            avg_rpm=("rpm", "mean"),
            anomalies_count=("is_isolation_anomaly", "sum"),
            avg_risk_score=("risk_score", "mean"),
            max_risk_score=("risk_score", "max"),
            failure_probability=("failure_probability", "mean"),
        )
    )

    anomaly_results.to_sql(
        "mart_pump_anomalies",
        engine,
        if_exists="replace",
        index=False
    )

    pump_risk_daily.to_sql(
        "mart_pump_risk_daily",
        engine,
        if_exists="replace",
        index=False
    )

    metrics.to_sql(
        "ml_failure_metrics",
        engine,
        if_exists="replace",
        index=False
    )

    print(f"mart_pump_anomalies: {len(anomaly_results)} rows saved")
    print(f"mart_pump_risk_daily: {len(pump_risk_daily)} rows saved")
    print(metrics)


if __name__ == "__main__":
    main()