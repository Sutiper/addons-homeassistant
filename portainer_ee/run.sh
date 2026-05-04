#!/usr/bin/with-contenv bashio

bashio::log.info "Démarrage de Portainer Business Edition..."

exec /portainer \
  --data /data \
  --bind :9000 \
  --bind-https :9443 \
  --tunnel-port 8000
