FROM portainer/portainer-ee:sts

LABEL \
  io.hass.version="1.0.0" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
