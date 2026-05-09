# Base HA Alpine avec bashio et s6
FROM ghcr.io/home-assistant/base:latest

LABEL \
  io.hass.version="1.0.0" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64|armv7"

# OpenSSH + sftp-server + tzdata
RUN apk add --no-cache \
    openssh \
    openssh-sftp-server \
    tzdata \
    sudo \
    bash

# Répertoire pour les clés hôte persistantes
RUN mkdir -p /data/ssh

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
