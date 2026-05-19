# Big Data и ML Pipeline

Домашнее задание по дисциплине "Семинар наставника".

## Цель

Реализовать аналитический pipeline:

PostgreSQL → ETL → MinIO → обработка → Jupyter → витрины → Superset

## Сервисы

- PostgreSQL — исходные таблицы
- MinIO — S3-хранилище для parquet/csv
- JupyterHub — обработка данных и ML
- Apache Superset — BI-дашборды

## Структура проекта

- `data/sql` — SQL-скрипты создания и наполнения таблиц
- `src/etl` — выгрузка данных из PostgreSQL в MinIO
- `src/processing` — очистка, агрегации, feature engineering
- `src/ml` — обучение моделей и расчёт метрик
- `src/quality` — проверки качества данных
- `notebooks` — Jupyter-ноутбуки
- `superset` — материалы по BI-дашбордам
- `docs` — документация и скриншоты

## Запуск

```bash
docker compose up -d
```
