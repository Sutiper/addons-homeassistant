#!/usr/bin/with-contenv bashio

PUID=$(bashio::config 'PUID')
PGID=$(bashio::config 'PGID')
TZ=$(bashio::config 'TZ')
LC_ALL_VAL=$(bashio::config 'LC_ALL')
CONFIG_PATH=$(bashio::config 'CONFIG_PATH')

export PUID PGID TZ LC_ALL="$LC_ALL_VAL"
/init
