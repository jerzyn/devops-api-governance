#!/bin/sh
# Imports the OpenAPI contract into Microcks so contract tests have a service to
# run against. Runs as the `microcks-seed` compose service. Waits for Microcks
# (no dependency on its healthcheck), then uploads. Idempotent — re-upload just
# refreshes the artifact.
set -e

MICROCKS="http://microcks-uber:8080"
CONTRACT="/repo/contracts/orders-openapi.yaml"

echo "==> waiting for Microcks"
i=0
until curl -sf -o /dev/null "$MICROCKS/api/health"; do
  i=$((i + 1))
  [ "$i" -ge 60 ] && { echo "Microcks not ready"; exit 1; }
  sleep 2
done

echo "==> importing $CONTRACT"
curl -sf -X POST -F "file=@$CONTRACT" \
  "$MICROCKS/api/artifact/upload?mainArtifact=true"
echo
echo "==> microcks seed complete"
