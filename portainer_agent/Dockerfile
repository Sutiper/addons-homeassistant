# Stage 1 : image officielle Portainer Agent (basée sur scratch)
FROM portainer/agent:latest AS agent_src

# Stage 2 : image de base HA (Alpine + bashio + shell)
FROM ghcr.io/home-assistant/base:latest

LABEL \
  io.hass.version="1.0.0" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

# Copie du répertoire /app qui contient le binaire agent
# (l'image portainer/agent utilise WorkingDir=/app avec entrypoint ./agent)
COPY --from=agent_src /app /app

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
