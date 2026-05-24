DROP VIEW IF EXISTS vw_heatmap_pressure_debit;
DROP VIEW IF EXISTS vw_bar_chart_top_wells;
DROP VIEW IF EXISTS vw_line_chart_production;
DROP VIEW IF EXISTS vw_pressure_temperature_analysis;
DROP VIEW IF EXISTS vw_worst_wells;
DROP VIEW IF EXISTS vw_best_wells;
DROP VIEW IF EXISTS vw_well_kpi;
DROP VIEW IF EXISTS vw_daily_production;


-- 1. Общая добыча по дням
CREATE OR REPLACE VIEW vw_daily_production AS
SELECT
    date,
    ROUND(SUM(oil_tons)::NUMERIC, 2) AS total_oil_tons,
    ROUND(AVG(oil_tons)::NUMERIC, 2) AS avg_oil_tons
FROM mart_production
GROUP BY date
ORDER BY date;


-- 2. KPI по скважинам
CREATE OR REPLACE VIEW vw_well_kpi AS
SELECT
    well_id,
    well_name,
    ROUND(AVG(oil_tons)::NUMERIC, 2) AS avg_oil_tons,
    ROUND(AVG(downtime_pct)::NUMERIC, 2) AS downtime_percent,
    ROUND(AVG(avg_pressure)::NUMERIC, 2) AS avg_pressure,
    ROUND(AVG(avg_temperature)::NUMERIC, 2) AS avg_temperature
FROM mart_production
GROUP BY well_id, well_name
ORDER BY avg_oil_tons DESC;


-- 3. Лучшие и худшие скважины по среднему дебиту
CREATE OR REPLACE VIEW vw_best_wells AS
SELECT *
FROM vw_well_kpi
ORDER BY avg_oil_tons DESC
LIMIT 5;

CREATE OR REPLACE VIEW vw_worst_wells AS
SELECT *
FROM vw_well_kpi
ORDER BY avg_oil_tons ASC
LIMIT 5;


-- 4. Влияние температуры и давления на дебит
CREATE OR REPLACE VIEW vw_pressure_temperature_analysis AS
SELECT
    date,
    well_id,
    well_name,
    avg_pressure,
    avg_temperature,
    oil_tons,
    CASE
        WHEN avg_pressure < 90 THEN 'low'
        WHEN avg_pressure < 110 THEN 'medium'
        ELSE 'high'
    END AS pressure_group
FROM mart_production;


-- 5. Датасет для Line Chart: добыча по времени
CREATE OR REPLACE VIEW vw_line_chart_production AS
SELECT
    date,
    total_oil_tons
FROM vw_daily_production
ORDER BY date;


-- 6. Датасет для Bar Chart: топ скважин по среднему дебиту
CREATE OR REPLACE VIEW vw_bar_chart_top_wells AS
SELECT
    well_name,
    avg_oil_tons,
    downtime_percent
FROM vw_well_kpi
ORDER BY avg_oil_tons DESC;


-- 7. Датасет для Heatmap: давление и температура vs средний дебит
CREATE OR REPLACE VIEW vw_heatmap_pressure_debit AS
SELECT
    ROUND(avg_pressure::NUMERIC, 0) AS pressure_bucket,
    ROUND(avg_temperature::NUMERIC, 0) AS temperature_bucket,
    ROUND(AVG(oil_tons)::NUMERIC, 2) AS avg_oil_tons
FROM mart_production
GROUP BY
    ROUND(avg_pressure::NUMERIC, 0),
    ROUND(avg_temperature::NUMERIC, 0)
ORDER BY
    pressure_bucket,
    temperature_bucket;
