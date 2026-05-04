# Stage 1 : image officielle Portainer Agent (basée sur scratch)
FROM portainer/agent:latest AS agent_src

# Stage 2 : image de base HA (Alpine + bashio + shell)
FROM ghcr.io/home-assistant/base:latest

LABEL \
  io.hass.version="1.0.0" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

# Copie du binaire Agent depuis l'image officielle
COPY --from=agent_src /agent /agent

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
