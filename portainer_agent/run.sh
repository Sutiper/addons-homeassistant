#!/usr/bin/with-contenv bashio

bashio::log.info "Démarrage de Portainer Edge Agent..."

EDGE_KEY=$(bashio::config 'edge_key')
EDGE_ID=$(bashio::config 'edge_id')
EDGE_INSECURE_POLL=$(bashio::config 'edge_insecure_poll')
LOG_LEVEL=$(bashio::config 'log_level')

if bashio::var.is_empty "${EDGE_KEY}"; then
  bashio::log.fatal "edge_key est obligatoire."
  bashio::log.fatal "Génère-la dans Portainer > Environments > Add > Edge Agent Standard."
  exit 1
fi

if bashio::var.is_empty "${EDGE_ID}"; then
  bashio::log.fatal "edge_id est obligatoire."
  bashio::log.fatal "Ex: homeassistant-rpi5"
  exit 1
fi

export EDGE=1
export EDGE_KEY="${EDGE_KEY}"
export EDGE_ID="${EDGE_ID}"
export LOG_LEVEL="${LOG_LEVEL}"

if bashio::var.true "${EDGE_INSECURE_POLL}"; then
  export EDGE_INSECURE_POLL=1
  bashio::log.warning "Mode insecure poll activé (TLS non vérifié)."
else
  export EDGE_INSECURE_POLL=0
fi

bashio::log.info "Edge ID    : ${EDGE_ID}"
bashio::log.info "Log level  : ${LOG_LEVEL}"

exec /agent
