FROM portainer/portainer-ee:sts

LABEL \
  io.hass.version="sts" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

VOLUME /data
EXPOSE 9000 9443 8000

ENTRYPOINT ["/portainer"]
