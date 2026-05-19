#!/bin/sh
set -eu

if ! id "$JUPYTERHUB_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$JUPYTERHUB_USER"
fi

echo "$JUPYTERHUB_USER:$JUPYTERHUB_PASSWORD" | chpasswd

mkdir -p "/home/$JUPYTERHUB_USER/work"
chown -R "$JUPYTERHUB_USER:$JUPYTERHUB_USER" "/home/$JUPYTERHUB_USER" /srv/jupyterhub

exec "$@"
