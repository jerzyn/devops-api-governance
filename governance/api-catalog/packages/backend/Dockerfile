# Self-contained single-stage build for the governance catalog Backstage backend.
# Builds and runs in one Node 24 image, so no host Node/Yarn is required —
# `docker compose --profile catalog build backstage` is all that's needed.
# (Single stage keeps node_modules in the image, avoiding the skeleton/bundle
# production-install dance that needs the yarn workspace-tools plugin.)
#
# Build context is the Backstage app root (./backstage).

FROM node:24-bookworm-slim

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

# Enable corepack (yarn 4 from packageManager) as root — it symlinks into
# /usr/local/bin, which the unprivileged node user cannot write.
RUN corepack enable

USER node
WORKDIR /app
ENV NODE_OPTIONS="--no-node-snapshot"

# Copy the whole app and install. Not --immutable: the lockfile seeded by
# create-app --skip-install is completed on first real install, and the
# `yarn add` below mutates it anyway.
COPY --chown=node:node . .

RUN yarn install

# governance demo: add the Gitea entity provider (resolved by yarn for this line).
# NOTE: @microcks/microcks-backstage-provider is intentionally NOT added — 0.0.7
# is incompatible with this Backstage line (see packages/backend/src/index.ts).
RUN yarn workspace backend add \
      @backstage/plugin-catalog-backend-module-gitea

RUN yarn tsc
RUN yarn build:backend

# build:backend emits only bundle.tar.gz; unpack it in place so
# packages/backend/dist/index.cjs.js (the runnable backend) exists. node_modules
# from `yarn install` above stays available to it.
RUN tar xzf packages/backend/dist/bundle.tar.gz -C /app

ENV NODE_ENV=production
EXPOSE 7007
CMD ["node", "packages/backend", "--config", "app-config.yaml"]
