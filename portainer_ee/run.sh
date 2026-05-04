#!/bin/sh
echo "Démarrage de Portainer Business Edition..."
exec /portainer \
  --data /data \
  --bind :9000 \
  --bind-https :9443 \
  --tunnel-port 8000
