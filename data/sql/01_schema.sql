BEGIN;

DROP TABLE IF EXISTS deliveries CASCADE;
DROP TABLE IF EXISTS pump_failures CASCADE;
DROP TABLE IF EXISTS pump_sensors CASCADE;
DROP TABLE IF EXISTS well_targets CASCADE;
DROP TABLE IF EXISTS telemetry CASCADE;
DROP TABLE IF EXISTS production CASCADE;
DROP TABLE IF EXISTS wells CASCADE;

CREATE TABLE wells (
    well_id INTEGER PRIMARY KEY,
    well_name VARCHAR(50) NOT NULL UNIQUE,
    field_name VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    depth_m INTEGER NOT NULL CHECK (depth_m > 0),
    status VARCHAR(30) NOT NULL CHECK (status IN ('active', 'maintenance', 'inactive'))
);

CREATE TABLE production (
    production_id BIGSERIAL PRIMARY KEY,
    well_id INTEGER NOT NULL REFERENCES wells(well_id),
    production_date DATE NOT NULL,
    oil_tons NUMERIC(10, 2) NOT NULL CHECK (oil_tons >= 0),
    water_tons NUMERIC(10, 2) NOT NULL CHECK (water_tons >= 0),
    gas_m3 NUMERIC(12, 2) NOT NULL CHECK (gas_m3 >= 0),
    downtime_hours NUMERIC(5, 2) NOT NULL CHECK (downtime_hours >= 0 AND downtime_hours <= 24),
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (well_id, production_date)
);

CREATE TABLE telemetry (
    telemetry_id BIGSERIAL PRIMARY KEY,
    well_id INTEGER NOT NULL REFERENCES wells(well_id),
    sensor_ts TIMESTAMP NOT NULL,
    pressure_atm NUMERIC(10, 2) NOT NULL,
    temperature_c NUMERIC(10, 2) NOT NULL,
    energy_kwh NUMERIC(12, 2) NOT NULL CHECK (energy_kwh >= 0),
    pump_power_kw NUMERIC(10, 2) NOT NULL CHECK (pump_power_kw >= 0),
    pump_runtime_hours NUMERIC(5, 2) NOT NULL CHECK (pump_runtime_hours >= 0 AND pump_runtime_hours <= 24),
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (well_id, sensor_ts)
);

CREATE TABLE well_targets (
    target_id BIGSERIAL PRIMARY KEY,
    well_id INTEGER NOT NULL REFERENCES wells(well_id),
    target_date DATE NOT NULL,
    avg_pressure_atm NUMERIC(10, 2) NOT NULL,
    avg_temperature_c NUMERIC(10, 2) NOT NULL,
    avg_power_kw NUMERIC(10, 2) NOT NULL,
    pump_runtime_hours NUMERIC(5, 2) NOT NULL,
    target_oil_tons NUMERIC(10, 2) NOT NULL,
    UNIQUE (well_id, target_date)
);

CREATE TABLE pump_sensors (
    sensor_id BIGSERIAL PRIMARY KEY,
    pump_id VARCHAR(50) NOT NULL,
    well_id INTEGER NOT NULL REFERENCES wells(well_id),
    sensor_ts TIMESTAMP NOT NULL,
    vibration_mm_s NUMERIC(10, 2) NOT NULL,
    temperature_c NUMERIC(10, 2) NOT NULL,
    current_a NUMERIC(10, 2) NOT NULL,
    rpm NUMERIC(10, 2) NOT NULL,
    UNIQUE (pump_id, sensor_ts)
);

CREATE TABLE pump_failures (
    failure_id BIGSERIAL PRIMARY KEY,
    pump_id VARCHAR(50) NOT NULL,
    well_id INTEGER NOT NULL REFERENCES wells(well_id),
    failure_ts TIMESTAMP NOT NULL,
    failure_type VARCHAR(100) NOT NULL,
    severity INTEGER NOT NULL CHECK (severity BETWEEN 1 AND 5),
    repair_hours NUMERIC(6, 2) NOT NULL CHECK (repair_hours >= 0)
);

CREATE TABLE deliveries (
    delivery_id BIGSERIAL PRIMARY KEY,
    delivery_date DATE NOT NULL,
    route VARCHAR(100) NOT NULL,
    distance_km NUMERIC(10, 2) NOT NULL CHECK (distance_km > 0),
    volume_tons NUMERIC(10, 2) NOT NULL CHECK (volume_tons > 0),
    cost_rub NUMERIC(14, 2) NOT NULL CHECK (cost_rub >= 0),
    delay_hours NUMERIC(6, 2) NOT NULL CHECK (delay_hours >= 0),
    weather VARCHAR(30) NOT NULL,
    driver VARCHAR(100) NOT NULL
);

CREATE INDEX idx_production_date ON production(production_date);
CREATE INDEX idx_production_well_date ON production(well_id, production_date);

CREATE INDEX idx_telemetry_ts ON telemetry(sensor_ts);
CREATE INDEX idx_telemetry_well_ts ON telemetry(well_id, sensor_ts);

CREATE INDEX idx_well_targets_date ON well_targets(target_date);
CREATE INDEX idx_pump_sensors_ts ON pump_sensors(sensor_ts);
CREATE INDEX idx_pump_failures_ts ON pump_failures(failure_ts);
CREATE INDEX idx_deliveries_date ON deliveries(delivery_date);

COMMIT;