#!/bin/sh
set -eu

superset db upgrade

superset fab create-admin \
  --username "$SUPERSET_ADMIN_USERNAME" \
  --firstname Superset \
  --lastname Admin \
  --email "$SUPERSET_ADMIN_EMAIL" \
  --password "$SUPERSET_ADMIN_PASSWORD" || true

superset init

exec superset run -h 0.0.0.0 -p 8088
