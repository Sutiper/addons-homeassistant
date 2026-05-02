<<<<<<< HEAD
ARG BUILD_FROM=portainer/portainer-ee:sts
=======
ARG BUILD_FROM
>>>>>>> c21932f888c0ab277c7b41bea086b5357c682a06
FROM portainer/portainer-ee:sts AS portainer_src

FROM $BUILD_FROM
COPY --from=portainer_src /portainer /portainer
COPY --from=portainer_src /public /public
COPY run.sh /run.sh
RUN chmod a+x /run.sh
