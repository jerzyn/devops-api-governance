# Job image for the PR-governance workflows (REST and events): Node 24 with
# every tool the gates use already installed, so CI runs don't download
# anything (faster, and no failures from a flaky connection). The workflows
# still install a tool themselves when it is missing, so they also run on a
# plain node runner. Node 24 because @asyncapi/cli 6.x needs Node 24.11+.
FROM docker.io/library/node:24-bookworm

# REST gates
ARG OPENLINT_VERSION=1.2.0
ARG JS_YAML_VERSION=4.1.0
ARG OASDIFF_VERSION=1.19.0
# The CLI only validates the KrakenD v3 config schema, so it doesn't have to
# match the gateway image (krakend:2.13.11 in docker-compose.yml). 2.6.2 is
# the build that the REST gate was written against.
ARG KRAKEND_VERSION=2.6.2
# Event gates
ARG ASYNCAPI_CLI_VERSION=6.3.0
ARG ASYNCAPI_PARSER_VERSION=3.6.6
ARG ASYNCAPI_DIFF_VERSION=0.6.0
# MQTT command line client (mqtt pub / mqtt sub), from npm instead of apt.
ARG MQTT_VERSION=5.16.1
# Kafka client for the broker policy check on Kafka.
ARG KAFKAJS_VERSION=2.2.4

# Nothing in a governance toolchain should phone home: opt out of install-time
# analytics (Scarf) and update checks here, and of the AsyncAPI CLI's own
# analytics below.
ENV SCARF_ANALYTICS=false \
    DO_NOT_TRACK=1 \
    NO_UPDATE_NOTIFIER=1

RUN npm install -g \
      "openlint@${OPENLINT_VERSION}" \
      "js-yaml@${JS_YAML_VERSION}" \
      "@asyncapi/cli@${ASYNCAPI_CLI_VERSION}" \
      "@asyncapi/parser@${ASYNCAPI_PARSER_VERSION}" \
      "@asyncapi/diff@${ASYNCAPI_DIFF_VERSION}" \
      "mqtt@${MQTT_VERSION}" \
      "kafkajs@${KAFKAJS_VERSION}" \
 && npm cache clean --force
# Governance scripts (gateway generator, contract test, diff, broker policy)
# require js-yaml, the parser and the diff; resolve them from the global install.
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
 && rm -rf /tmp/*

RUN asyncapi config analytics --disable \
 && openlint --version && oasdiff --version && krakend version \
 && asyncapi --version && mqtt version
