# Same base image family as gitea-seed (docker:27-cli) for a trusted,
# already-used-in-this-repo docker/podman CLI, plus Node for server.js.
FROM docker:27-cli
RUN apk add --no-cache nodejs
# docker:27-cli sets ENTRYPOINT ["docker-entrypoint.sh"], which rewrites its
# command to "docker <cmd>" whenever the first arg is a valid docker
# subcommand (see the image's docker-entrypoint.sh: `docker help "$1"`).
# "node" IS a valid docker subcommand ("docker node ..."), so without
# resetting ENTRYPOINT here, `CMD ["node", "server.js"]` silently becomes
# `docker node server.js` and server.js never runs.
ENTRYPOINT []
WORKDIR /app
COPY server.js .
ENV PORT=9000
ENV CONFIG_PATH=/shared/krakend.json
ENV KRAKEND_CONTAINER=krakend
ENV CONTAINER_ENGINE=docker
EXPOSE 9000
CMD ["node", "server.js"]
