# Job image for the PR-governance workflow: node:20-bullseye with every tool the
# gates use already installed, so CI runs don't download anything (faster, and
# no failures from a flaky connection). The workflow still installs a tool
# itself when it is missing, so it also runs on a plain node:20 runner.
FROM docker.io/library/node:20-bullseye

ARG SPECTRAL_VERSION=6.16.3
ARG JS_YAML_VERSION=4.1.0
ARG OASDIFF_VERSION=1.19.0
# The CLI only validates the KrakenD v3 config schema, so it doesn't have to
# match the gateway image (krakend:2.13.11 in docker-compose.yml). Newer CLI
# builds need glibc 2.32+/2.34+; bullseye has 2.31, and 2.6.2 runs on it.
ARG KRAKEND_VERSION=2.6.2

RUN npm install -g "@stoplight/spectral-cli@${SPECTRAL_VERSION}" "js-yaml@${JS_YAML_VERSION}" \
 && npm cache clean --force
# The gateway generator requires js-yaml; resolve it from the global install.
ENV NODE_PATH=/usr/local/lib/node_modules

# Binaries for the base image's own architecture (amd64 on most PCs, arm64 on
# Apple Silicon; both tools publish both), so they always match the image.
RUN set -e; cd /tmp \
 && ARCH="$(dpkg --print-architecture)" \
 && case "$ARCH" in amd64|arm64) ;; *) echo "unsupported architecture: $ARCH" >&2; exit 1 ;; esac \
 && curl -fsSL -o oasdiff.tgz "https://github.com/oasdiff/oasdiff/releases/download/v${OASDIFF_VERSION}/oasdiff_${OASDIFF_VERSION}_linux_${ARCH}.tar.gz" \
 && tar -xzf oasdiff.tgz oasdiff && install -m 0755 oasdiff /usr/local/bin/oasdiff \
 && curl -fsSL -o krakend.tgz "https://github.com/krakend/krakend-ce/releases/download/v${KRAKEND_VERSION}/krakend_${KRAKEND_VERSION}_${ARCH}_generic-linux.tar.gz" \
 && tar -xzf krakend.tgz && install -m 0755 usr/bin/krakend /usr/local/bin/krakend \
 && rm -rf /tmp/* \
 && spectral --version && oasdiff --version && krakend version
