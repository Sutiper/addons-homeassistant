FROM portainer/agent:latest

LABEL \
  io.hass.version="latest" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
