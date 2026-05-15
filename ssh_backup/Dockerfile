FROM ghcr.io/home-assistant/base:latest

LABEL \
  io.hass.version="1.0.9" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64|armv7"

RUN apk add --no-cache \
    openssh \
    openssh-sftp-server \
    tzdata \
    sudo \
    bash

RUN mkdir -p /data/ssh

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
