# Same base as krakend-deployer: the docker CLI (talks to Docker or to the
# Podman socket) plus Node for server.js. busybox tar unpacks the uploads.
FROM docker.io/library/docker:27-cli
RUN apk add --no-cache nodejs
# docker:27-cli's entrypoint turns `node ...` into `docker node ...`.
ENTRYPOINT []
WORKDIR /app
COPY server.js .
ENV PORT=9200
ENV CONTAINER_ENGINE=docker
ENV TARGETS=backend,mqtt-backend
EXPOSE 9200
CMD ["node", "server.js"]
