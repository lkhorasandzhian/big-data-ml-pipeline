\echo '== Tables =='

SELECT
    table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
      'wells',
      'production',
      'telemetry',
      'well_targets',
      'pump_sensors',
      'pump_failures',
      'deliveries'
  )
ORDER BY table_name;

\echo '== Row counts =='

SELECT 'wells' AS table_name, count(*) AS rows_count FROM wells
UNION ALL
SELECT 'production', count(*) FROM production
UNION ALL
SELECT 'telemetry', count(*) FROM telemetry
UNION ALL
SELECT 'well_targets', count(*) FROM well_targets
UNION ALL
SELECT 'pump_sensors', count(*) FROM pump_sensors
UNION ALL
SELECT 'pump_failures', count(*) FROM pump_failures
UNION ALL
SELECT 'deliveries', count(*) FROM deliveries
ORDER BY table_name;

\echo '== Date ranges =='

SELECT
    'production' AS table_name,
    min(production_date) AS min_date,
    max(production_date) AS max_date
FROM production
UNION ALL
SELECT
    'telemetry',
    min(sensor_ts::date),
    max(sensor_ts::date)
FROM telemetry
UNION ALL
SELECT
    'well_targets',
    min(target_date),
    max(target_date)
FROM well_targets
UNION ALL
SELECT
    'pump_sensors',
    min(sensor_ts::date),
    max(sensor_ts::date)
FROM pump_sensors
UNION ALL
SELECT
    'deliveries',
    min(delivery_date),
    max(delivery_date)
FROM deliveries;

\echo '== Sample production data =='

SELECT
    p.production_date,
    w.well_name,
    p.oil_tons,
    p.water_tons,
    p.gas_m3,
    p.downtime_hours
FROM production p
JOIN wells w ON w.well_id = p.well_id
ORDER BY p.production_date, w.well_id
LIMIT 10;