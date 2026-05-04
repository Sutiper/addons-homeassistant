FROM portainer/agent:latest

RUN apk add --no-cache jq

LABEL \
  io.hass.version="1.0.0" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
