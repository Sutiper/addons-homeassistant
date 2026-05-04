#!/bin/sh

CONFIG=/data/options.json

EDGE_KEY=$(jq -r '.edge_key' "$CONFIG")
EDGE_ID=$(jq -r '.edge_id' "$CONFIG")
EDGE_INSECURE_POLL=$(jq -r '.edge_insecure_poll' "$CONFIG")
LOG_LEVEL=$(jq -r '.log_level' "$CONFIG")

if [ -z "$EDGE_KEY" ] || [ "$EDGE_KEY" = "null" ] || [ "$EDGE_KEY" = "" ]; then
  echo "ERREUR: edge_key est obligatoire."
  echo "Génère-la dans Portainer > Environments > Add > Edge Agent Standard."
  exit 1
fi

if [ -z "$EDGE_ID" ] || [ "$EDGE_ID" = "null" ] || [ "$EDGE_ID" = "" ]; then
  echo "ERREUR: edge_id est obligatoire."
  echo "Choisis un identifiant unique (ex: homeassistant-rpi5)."
  exit 1
fi

export EDGE=1
export EDGE_KEY="$EDGE_KEY"
export EDGE_ID="$EDGE_ID"
export LOG_LEVEL="$LOG_LEVEL"

if [ "$EDGE_INSECURE_POLL" = "true" ]; then
  export EDGE_INSECURE_POLL=1
  echo "ATTENTION: Mode insecure poll activé."
else
  export EDGE_INSECURE_POLL=0
fi

echo "Démarrage Portainer Edge Agent..."
echo "Edge ID    : $EDGE_ID"
echo "Log level  : $LOG_LEVEL"

exec /agent
