CREATE OR REPLACE VIEW vw_pump_anomalies_time AS
SELECT
    sensor_datetime,
    sensor_date,
    pump_id,
    well_id,
    vibration,
    temperature,
    current_amp,
    rpm,
    zscore_max,
    is_zscore_anomaly,
    is_isolation_anomaly,
    risk_score,
    failure_probability
FROM mart_pump_anomalies;

CREATE OR REPLACE VIEW vw_vibration_before_failure AS
SELECT
    sensor_datetime,
    sensor_date,
    pump_id,
    well_id,
    vibration,
    failure_next_7d,
    risk_score
FROM mart_pump_anomalies
WHERE failure_next_7d = 1;

CREATE OR REPLACE VIEW vw_pump_risk_score AS
SELECT
    sensor_date,
    pump_id,
    well_id,
    avg_vibration,
    avg_temperature,
    avg_current_amp,
    avg_rpm,
    anomalies_count,
    avg_risk_score,
    max_risk_score,
    failure_probability
FROM mart_pump_risk_daily;