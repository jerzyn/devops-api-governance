#!/bin/sh
# Imports the contracts into Microcks so mocks and contract tests have a
# service to run against. Runs as the `microcks-seed` compose service (the REST and
# the MQTT contract) and `microcks-seed-kafka` (CONTRACTS=the Kafka contract).
# Waits for Microcks (no dependency on its healthcheck), then uploads.
# Idempotent: a re-upload just refreshes the artifact.
set -e

MICROCKS="http://microcks-uber:8080"
CONTRACTS="${CONTRACTS:-/repo/contracts/orders-openapi.yaml /repo/contracts/order-events-asyncapi.yaml}"

echo "==> waiting for Microcks"
i=0
until curl -sf -o /dev/null "$MICROCKS/api/health"; do
  i=$((i + 1))
  [ "$i" -ge 60 ] && { echo "Microcks not ready"; exit 1; }
  sleep 2
done

# The async minion's contract tests connect to the MQTT broker with the
# account named in the test's secret (the broker refuses anonymous clients).
echo "==> broker secret for async contract tests"
if curl -sf "$MICROCKS/api/secrets" | grep -q '"name":"mqtt-broker"'; then
  echo "    exists"
else
  curl -sf -X POST "$MICROCKS/api/secrets" -H 'Content-Type: application/json' \
    -d '{"name":"mqtt-broker","description":"Broker account of the Microcks async minion","username":"microcks","password":"microcks"}'
  echo
fi

for c in $CONTRACTS; do
  [ -f "$c" ] || { echo "==> skipping $c (not mounted)"; continue; }
  echo "==> importing $c"
  curl -sf -X POST -F "file=@$c" "$MICROCKS/api/artifact/upload?mainArtifact=true"
  echo
done
echo "==> microcks seed complete"
