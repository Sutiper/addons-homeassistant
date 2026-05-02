ARG BUILD_FROM=portainer/agent:latest
FROM portainer/agent:latest AS portainer_src

FROM $BUILD_FROM
COPY --from=portainer_src /agent /agent
COPY run.sh /run.sh
RUN chmod a+x /run.sh
