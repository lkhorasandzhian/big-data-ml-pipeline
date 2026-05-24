CREATE OR REPLACE VIEW vw_ml_predictions AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY production_date, well_id
    ) AS id,
    well_id,
    production_date,
    actual,
    predicted,
    error,
    avg_pressure,
    avg_temperature,
    avg_power,
    avg_pump_hours
FROM ml_predictions;

CREATE OR REPLACE VIEW vw_ml_metrics AS
SELECT
    model_name,
    mae,
    rmse
FROM ml_metrics;