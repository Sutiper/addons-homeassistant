ARG BUILD_FROM=portainer/portainer-ee:sts
FROM portainer/portainer-ee:sts AS portainer_src

FROM $BUILD_FROM
COPY --from=portainer_src /portainer /portainer
COPY --from=portainer_src /public /public
COPY run.sh /run.sh
RUN chmod a+x /run.sh
