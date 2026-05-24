-- Статистика задержек по погодным условиям.
CREATE OR REPLACE VIEW vw_logistics_weather_delay AS
SELECT
    weather,
    COUNT(*) AS deliveries_count,
    ROUND(AVG(delay_hours), 2) AS avg_delay_hours,
    ROUND(MAX(delay_hours), 2) AS max_delay_hours
FROM deliveries
GROUP BY weather
ORDER BY avg_delay_hours DESC;

-- Детальные данные поставок с расчетом стоимости за километр.
CREATE OR REPLACE VIEW vw_logistics_cost_distance AS
SELECT
    delivery_id,
    delivery_date,
    route,
    driver,
    weather,
    distance_km,
    volume_tons,
    cost_rub,
    delay_hours,
    ROUND(cost_rub / NULLIF(distance_km, 0), 2) AS cost_per_km
FROM deliveries;

-- KPI водителей по задержкам и стоимости перевозок.
CREATE OR REPLACE VIEW vw_driver_kpi AS
SELECT
    driver,
    COUNT(*) AS deliveries_count,
    ROUND(AVG(delay_hours), 2) AS avg_delay_hours,
    ROUND(MAX(delay_hours), 2) AS max_delay_hours,
    ROUND(AVG(cost_rub), 2) AS avg_delivery_cost_rub,
    ROUND(AVG(cost_rub / NULLIF(distance_km, 0)), 2) AS avg_cost_per_km,
    ROUND(SUM(volume_tons), 2) AS total_volume_tons
FROM deliveries
GROUP BY driver
ORDER BY avg_delay_hours ASC;

-- Аналитика маршрутов для оценки задержек, расстояний и стоимости.
CREATE OR REPLACE VIEW vw_route_analytics AS
SELECT
    route,
    COUNT(*) AS deliveries_count,
    ROUND(AVG(distance_km), 2) AS avg_distance_km,
    ROUND(AVG(delay_hours), 2) AS avg_delay_hours,
    ROUND(MAX(delay_hours), 2) AS max_delay_hours,
    ROUND(AVG(cost_rub), 2) AS avg_cost_rub,
    ROUND(AVG(cost_rub / NULLIF(distance_km, 0)), 2) AS avg_cost_per_km,
    ROUND(SUM(volume_tons), 2) AS total_volume_tons
FROM deliveries
GROUP BY route
ORDER BY avg_delay_hours DESC;