ARG BUILD_FROM
FROM lscr.io/linuxserver/chrome:latest

# On garde la structure du tuto pour que le Supervisor soit content
COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
