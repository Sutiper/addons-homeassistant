<<<<<<< HEAD
ARG BUILD_FROM=portainer/agent:latest
=======
ARG BUILD_FROM
>>>>>>> c21932f888c0ab277c7b41bea086b5357c682a06
FROM portainer/agent:latest AS portainer_src

FROM $BUILD_FROM
COPY --from=portainer_src /agent /agent
COPY run.sh /run.sh
RUN chmod a+x /run.sh
