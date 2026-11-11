# Job image for the PR-governance workflow: Node 24 with every tool the gates
# use already installed, so CI runs don't download anything. Node 24 because
# @asyncapi/cli 6.x needs Node 24.11 or newer.
FROM docker.io/library/node:24-bookworm

ARG ASYNCAPI_CLI_VERSION=6.3.0
ARG ASYNCAPI_PARSER_VERSION=3.6.6
ARG ASYNCAPI_DIFF_VERSION=0.6.0
ARG OPENLINT_VERSION=1.1.3
ARG JS_YAML_VERSION=4.1.0
# MQTT command line client (mqtt pub / mqtt sub), from npm instead of apt.
ARG MQTT_VERSION=5.16.1

# Nothing in a governance toolchain should phone home: opt out of install-time
# analytics (Scarf) and update checks here, and of the AsyncAPI CLI's own
# analytics below.
ENV SCARF_ANALYTICS=false \
    DO_NOT_TRACK=1 \
    NO_UPDATE_NOTIFIER=1

RUN npm install -g \
      "@asyncapi/cli@${ASYNCAPI_CLI_VERSION}" \
      "@asyncapi/parser@${ASYNCAPI_PARSER_VERSION}" \
      "@asyncapi/diff@${ASYNCAPI_DIFF_VERSION}" \
      "openlint@${OPENLINT_VERSION}" \
      "js-yaml@${JS_YAML_VERSION}" \
      "mqtt@${MQTT_VERSION}" \
 && npm cache clean --force
# Governance scripts require the parser, diff and js-yaml; resolve them from
# the global install.
ENV NODE_PATH=/usr/local/lib/node_modules

RUN asyncapi config analytics --disable \
 && asyncapi --version && openlint --version && mqtt version
