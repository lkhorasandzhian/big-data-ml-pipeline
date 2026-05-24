
# Архитектура

Архитектура pipeline:

PostgreSQL → ETL → MinIO → Processing → ML → Superset

Компоненты:

- PostgreSQL хранит исходные данные
- MinIO хранит parquet-датасеты
- JupyterHub выполняет обработку данных и ML
- Superset используется для BI-дашбордов
