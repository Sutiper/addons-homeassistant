FROM portainer/portainer-ee:sts

LABEL \
  io.hass.version="2.40.0" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

VOLUME /data
EXPOSE 9000 9443 8000

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
