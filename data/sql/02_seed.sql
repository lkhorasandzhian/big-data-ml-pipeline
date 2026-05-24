BEGIN;

TRUNCATE TABLE
    deliveries,
    pump_failures,
    pump_sensors,
    well_targets,
    telemetry,
    production,
    wells
RESTART IDENTITY CASCADE;

INSERT INTO wells (well_id, well_name, field_name, region, start_date, depth_m, status)
VALUES
    (1, 'WELL-001', 'North Field', 'West Siberia', '2019-03-15', 2450, 'active'),
    (2, 'WELL-002', 'North Field', 'West Siberia', '2020-06-20', 2510, 'active'),
    (3, 'WELL-003', 'North Field', 'West Siberia', '2018-11-02', 2380, 'maintenance'),
    (4, 'WELL-004', 'South Field', 'Volga Region', '2021-04-10', 2200, 'active'),
    (5, 'WELL-005', 'South Field', 'Volga Region', '2021-08-18', 2275, 'active'),
    (6, 'WELL-006', 'East Field', 'Ural Region', '2022-01-25', 2600, 'active'),
    (7, 'WELL-007', 'East Field', 'Ural Region', '2020-09-30', 2550, 'inactive'),
    (8, 'WELL-008', 'West Field', 'Perm Region', '2019-12-05', 2325, 'active');

WITH dates AS (
    SELECT gs::date AS production_date
    FROM generate_series('2024-01-01'::date, '2024-03-31'::date, interval '1 day') AS gs
)
INSERT INTO production (
    well_id,
    production_date,
    oil_tons,
    water_tons,
    gas_m3,
    downtime_hours
)
SELECT
    w.well_id,
    d.production_date,
    round((
        70
        + w.well_id * 4
        + sin(extract(doy FROM d.production_date)::double precision / 6.0) * 8
        - CASE WHEN w.status = 'maintenance' THEN 15 ELSE 0 END
        - CASE WHEN w.status = 'inactive' THEN 35 ELSE 0 END
    )::numeric, 2) AS oil_tons,
    round((
        12
        + w.well_id * 1.5
        + cos(extract(doy FROM d.production_date)::double precision / 8.0) * 3
    )::numeric, 2) AS water_tons,
    round((
        900
        + w.well_id * 70
        + sin(extract(doy FROM d.production_date)::double precision / 5.0) * 120
    )::numeric, 2) AS gas_m3,
    round((
        CASE
            WHEN w.status = 'maintenance' THEN 4
            WHEN w.status = 'inactive' THEN 10
            WHEN ((w.well_id * 13 + extract(day FROM d.production_date)::int) % 11 = 0) THEN 2
            ELSE 0.5
        END
    )::numeric, 2) AS downtime_hours
FROM wells w
CROSS JOIN dates d;

WITH dates AS (
    SELECT gs::date AS telemetry_date
    FROM generate_series('2024-01-01'::date, '2024-03-31'::date, interval '1 day') AS gs
),
hours AS (
    SELECT unnest(ARRAY[0, 6, 12, 18]) AS hour_step
)
INSERT INTO telemetry (
    well_id,
    sensor_ts,
    pressure_atm,
    temperature_c,
    energy_kwh,
    pump_power_kw,
    pump_runtime_hours
)
SELECT
    w.well_id,
    d.telemetry_date + make_interval(hours => h.hour_step) AS sensor_ts,
    round((
        95
        + w.well_id * 3
        + sin(extract(doy FROM d.telemetry_date)::double precision / 7.0) * 6
        + h.hour_step * 0.12
    )::numeric, 2) AS pressure_atm,
    round((
        64
        + w.well_id * 1.2
        + cos(extract(doy FROM d.telemetry_date)::double precision / 9.0) * 4
        + h.hour_step * 0.05
    )::numeric, 2) AS temperature_c,
    round((
        420
        + w.well_id * 18
        + h.hour_step * 3
        + sin(extract(doy FROM d.telemetry_date)::double precision / 4.0) * 20
    )::numeric, 2) AS energy_kwh,
    round((
        55
        + w.well_id * 2.3
        + sin(extract(doy FROM d.telemetry_date)::double precision / 6.0) * 4
    )::numeric, 2) AS pump_power_kw,
    round((
        CASE
            WHEN w.status = 'inactive' THEN 14
            WHEN w.status = 'maintenance' THEN 18
            ELSE 23
        END / 4.0
    )::numeric, 2) AS pump_runtime_hours
FROM wells w
CROSS JOIN dates d
CROSS JOIN hours h;

INSERT INTO well_targets (
    well_id,
    target_date,
    avg_pressure_atm,
    avg_temperature_c,
    avg_power_kw,
    pump_runtime_hours,
    target_oil_tons
)
SELECT
    p.well_id,
    p.production_date,
    round(avg(t.pressure_atm)::numeric, 2) AS avg_pressure_atm,
    round(avg(t.temperature_c)::numeric, 2) AS avg_temperature_c,
    round(avg(t.pump_power_kw)::numeric, 2) AS avg_power_kw,
    round(sum(t.pump_runtime_hours)::numeric, 2) AS pump_runtime_hours,
    p.oil_tons AS target_oil_tons
FROM production p
JOIN telemetry t
    ON t.well_id = p.well_id
   AND t.sensor_ts::date = p.production_date
GROUP BY
    p.well_id,
    p.production_date,
    p.oil_tons;

INSERT INTO pump_failures (
    pump_id,
    well_id,
    failure_ts,
    failure_type,
    severity,
    repair_hours
)
VALUES
    ('PUMP-002', 2, '2024-02-15 08:00:00', 'overheating', 3, 12),
    ('PUMP-003', 3, '2024-02-28 14:00:00', 'high vibration', 4, 24),
    ('PUMP-006', 6, '2024-03-12 10:00:00', 'current overload', 3, 10),
    ('PUMP-008', 8, '2024-03-24 16:00:00', 'bearing wear', 5, 36);

WITH dates AS (
    SELECT gs::date AS sensor_date
    FROM generate_series('2024-01-01'::date, '2024-03-31'::date, interval '1 day') AS gs
),
hours AS (
    SELECT unnest(ARRAY[0, 6, 12, 18]) AS hour_step
)
INSERT INTO pump_sensors (
    pump_id,
    well_id,
    sensor_ts,
    vibration_mm_s,
    temperature_c,
    current_a,
    rpm
)
SELECT
    'PUMP-' || lpad(w.well_id::text, 3, '0') AS pump_id,
    w.well_id,
    ts.sensor_ts,
    round((
        1.2
        + w.well_id * 0.12
        + sin(extract(doy FROM d.sensor_date)::double precision / 5.0) * 0.4
        + CASE
            WHEN EXISTS (
                SELECT 1
                FROM pump_failures f
                WHERE f.well_id = w.well_id
                  AND ts.sensor_ts BETWEEN f.failure_ts - interval '7 days' AND f.failure_ts
            )
            THEN 2.7
            ELSE 0
          END
    )::numeric, 2) AS vibration_mm_s,
    round((
        58
        + w.well_id * 1.4
        + h.hour_step * 0.08
        + CASE
            WHEN EXISTS (
                SELECT 1
                FROM pump_failures f
                WHERE f.well_id = w.well_id
                  AND ts.sensor_ts BETWEEN f.failure_ts - interval '7 days' AND f.failure_ts
            )
            THEN 9
            ELSE 0
          END
    )::numeric, 2) AS temperature_c,
    round((
        32
        + w.well_id * 1.7
        + sin(extract(doy FROM d.sensor_date)::double precision / 4.0) * 2
        + CASE
            WHEN EXISTS (
                SELECT 1
                FROM pump_failures f
                WHERE f.well_id = w.well_id
                  AND ts.sensor_ts BETWEEN f.failure_ts - interval '7 days' AND f.failure_ts
            )
            THEN 7
            ELSE 0
          END
    )::numeric, 2) AS current_a,
    round((
        1450
        + w.well_id * 12
        - CASE
            WHEN EXISTS (
                SELECT 1
                FROM pump_failures f
                WHERE f.well_id = w.well_id
                  AND ts.sensor_ts BETWEEN f.failure_ts - interval '7 days' AND f.failure_ts
            )
            THEN 120
            ELSE 0
          END
    )::numeric, 2) AS rpm
FROM wells w
CROSS JOIN dates d
CROSS JOIN hours h
CROSS JOIN LATERAL (
    SELECT d.sensor_date + make_interval(hours => h.hour_step) AS sensor_ts
) ts;

WITH src AS (
    SELECT gs AS n
    FROM generate_series(1, 120) AS gs
)
INSERT INTO deliveries (
    delivery_date,
    route,
    distance_km,
    volume_tons,
    cost_rub,
    delay_hours,
    weather,
    driver
)
SELECT
    ('2024-01-01'::date + ((n - 1) % 91))::date AS delivery_date,
    'Route-' || lpad((((n - 1) % 8) + 1)::text, 2, '0') AS route,
    round((80 + ((n * 17) % 220))::numeric, 2) AS distance_km,
    round((15 + ((n * 7) % 55))::numeric, 2) AS volume_tons,
    round((
        (80 + ((n * 17) % 220)) * (45 + ((n * 7) % 55) * 0.8)
        + CASE ((n - 1) % 4)
            WHEN 0 THEN 0
            WHEN 1 THEN 3500
            WHEN 2 THEN 7000
            ELSE 12000
          END
    )::numeric, 2) AS cost_rub,
    round((
        CASE ((n - 1) % 4)
            WHEN 0 THEN ((n % 3) * 0.5)
            WHEN 1 THEN 1.5 + (n % 4)
            WHEN 2 THEN 3.0 + (n % 5)
            ELSE 5.0 + (n % 7)
        END
    )::numeric, 2) AS delay_hours,
    CASE ((n - 1) % 4)
        WHEN 0 THEN 'clear'
        WHEN 1 THEN 'rain'
        WHEN 2 THEN 'snow'
        ELSE 'storm'
    END AS weather,
    'Driver-' || lpad((((n - 1) % 10) + 1)::text, 2, '0') AS driver
FROM src;

COMMIT;