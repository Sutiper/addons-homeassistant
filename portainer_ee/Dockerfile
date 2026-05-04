# Stage 1 : image officielle Portainer EE (basée sur scratch)
# On l'utilise uniquement pour extraire le binaire et les assets web
FROM portainer/portainer-ee:sts AS portainer_src

# Stage 2 : image de base HA (Alpine + bashio + shell)
FROM ghcr.io/home-assistant/base:latest

LABEL \
  io.hass.version="1.0.0" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

# Copie du binaire Portainer et des assets web depuis l'image officielle
COPY --from=portainer_src /portainer /portainer
COPY --from=portainer_src /public /public

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
