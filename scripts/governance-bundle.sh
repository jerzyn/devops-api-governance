#!/bin/sh
# Builds the lean governance repo that the consumer repos' CI clones (a link,
# not a vendored copy): every ruleset, custom function, gate script and the
# API guidelines with their TechDocs wiring. One repo for REST and for events.
#
#   governance-bundle.sh <governance dir> <output dir>
#
# Used by gitea-seed (scripts/seed-gitea.sh) and by the demo helper when it
# resets Gitea (scripts/demo/prep-stage.sh, scripts/demo/events/prep-stage.sh),
# so all three publish the same content. POSIX sh: gitea-seed runs on Alpine.
set -e

SRC="$1"; OUT="$2"
[ -d "$SRC" ] && [ -n "$OUT" ] || { echo "usage: $0 <governance dir> <output dir>" >&2; exit 1; }
rm -rf "$OUT"; mkdir -p "$OUT/gateway" "$OUT/broker-policy"

# OpenLint rulesets: OpenAPI, and the AsyncAPI rules with the MQTT and Kafka
# rulesets that extend them. functionsDir in each ruleset is relative, so the
# custom functions sit next to them.
cp "$SRC"/openlint/openlint-ruleset.yaml "$SRC"/openlint/asyncapi-*ruleset.yaml "$OUT"/
cp -r "$SRC/openlint/openlint-functions" "$OUT"/

# Guidelines + their TechDocs wiring, at the repo root so Backstage discovers
# the api-guidelines Component and renders it as TechDocs.
cp "$SRC/api-guidelines/mkdocs.yml" "$SRC/api-guidelines/catalog-info.yaml" "$OUT"/
cp -r "$SRC/api-guidelines/docs" "$OUT"/

# REST: the OpenAPI -> KrakenD generator. Its deployer/ is platform-side
# (built by docker-compose) and is not included.
cp "$SRC/gateway/generate.js" "$SRC/gateway/package.json" "$SRC/gateway/krakend-base.json" "$OUT/gateway/"

# Events: the async contract test runner, the breaking change checks
# (structural diff and registry compatibility) and the broker policy
# generator and its check (the deployer runs as a service).
cp -r "$SRC/contract-test" "$SRC/breaking-changes" "$OUT"/
cp "$SRC"/broker-policy/*.js "$OUT/broker-policy/"
