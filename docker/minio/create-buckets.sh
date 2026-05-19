#!/bin/sh
set -eu

echo "Waiting for MinIO..."

until mc alias set local "$MINIO_INTERNAL_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; do
  echo "MinIO is not ready yet. Retrying..."
  sleep 2
done

echo "Creating buckets..."

mc mb -p local/raw || true
mc mb -p local/processed || true
mc mb -p local/marts || true

mc ls local

echo "MinIO buckets are ready."
