FROM quay.io/jupyterhub/jupyterhub:5.3.0

USER root

COPY docker/jupyterhub/requirements.txt /tmp/jupyterhub-requirements.txt

RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    python -m pip install --no-cache-dir --prefer-binary -r /tmp/jupyterhub-requirements.txt

COPY docker/jupyterhub/jupyterhub_config.py /srv/jupyterhub/jupyterhub_config.py
COPY docker/jupyterhub/start.sh /srv/jupyterhub/start.sh

RUN chmod +x /srv/jupyterhub/start.sh

EXPOSE 8000

ENTRYPOINT ["/srv/jupyterhub/start.sh"]
CMD ["jupyterhub", "-f", "/srv/jupyterhub/jupyterhub_config.py", "--ip", "0.0.0.0", "--port", "8000"]