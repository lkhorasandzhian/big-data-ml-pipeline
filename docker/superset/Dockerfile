FROM apache/superset:5.0.0

USER root

RUN . /app/.venv/bin/activate && \
    uv pip install --no-cache-dir psycopg2-binary

COPY docker/superset/superset_config.py /app/pythonpath/superset_config.py
COPY docker/superset/superset_init.sh /app/docker/superset_init.sh

RUN chmod +x /app/docker/superset_init.sh

USER superset

ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py

EXPOSE 8088

ENTRYPOINT ["/app/docker/superset_init.sh"]