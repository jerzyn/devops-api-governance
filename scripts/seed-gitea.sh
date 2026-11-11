#!/bin/sh
# Seeds a fresh Gitea so the demo has content: admin user, organization, repo,
# pushed code, and a runner registration token (written to the shared volume for
# gitea-runner to consume). Runs as the `gitea-seed` compose service after Gitea
# is healthy. Idempotent.
set -e

U="${GITEA_ADMIN_USER:-demo}"
P="${GITEA_ADMIN_PASSWORD:-demo12345}"
ORG="${GITEA_ORG:-async-governance-demo}"
# Consumer (product) repo: the AsyncAPI contract, the backend that publishes
# the events and the subscriber.
# This is where PRs happen. Source: /repo (the example/ template folder).
REPO="${GITEA_REPO:-order-events-api}"
# The same API on Kafka, from /repo-kafka (the example-kafka/ folder). Its PRs
# need the kafka compose profile.
KAFKA_REPO="${GITEA_KAFKA_REPO:-order-events-kafka-api}"
# Central governance repo: the AsyncAPI ruleset and the guidelines. The
# consumer's CI clones this (a link, not a vendored copy). Source: /governance
# (the project root = governance context).
GOV_REPO="${GITEA_GOV_REPO:-async-api-governance}"
GITEA_CONTAINER="${GITEA_CONTAINER:-async-gitea}"
API="http://gitea:3000/api/v1"

echo "==> admin user '$U'"
docker exec -u git "$GITEA_CONTAINER" gitea admin user create \
  --admin --username "$U" --password "$P" --email "$U@example.com" \
  --must-change-password=false 2>/dev/null || echo "    already exists"

echo "==> organization '$ORG'"
curl -sf -o /dev/null -u "$U:$P" -X POST -H 'Content-Type: application/json' \
  -d "{\"username\":\"$ORG\"}" "$API/orgs" || echo "    already exists"

for r in "$REPO" "$KAFKA_REPO" "$GOV_REPO"; do
  echo "==> repository '$ORG/$r'"
  curl -sf -o /dev/null -u "$U:$P" -X POST -H 'Content-Type: application/json' \
    -d "{\"name\":\"$r\",\"private\":false}" "$API/orgs/$ORG/repos" || echo "    already exists"
done

# Materialize a fresh git repo from a source folder and force-push to Gitea.
# Used for both repos so the source folders need no committed .git of their own
# (the example/ template is plain tracked files in the project).
seed_repo() {
  src="$1"; name="$2"; msg="$3"
  tmp="/tmp/seed-$name"
  rm -rf "$tmp"; mkdir -p "$tmp"
  cp -a "$src"/. "$tmp"/
  rm -rf "$tmp/.git"
  git config --global --add safe.directory "$tmp"
  git -C "$tmp" init -q
  git -C "$tmp" -c user.email=seed@example.com -c user.name=seed add -A
  git -C "$tmp" -c user.email=seed@example.com -c user.name=seed commit -qm "$msg"
  git -C "$tmp" push -f "http://$U:$P@gitea:3000/$ORG/$name.git" HEAD:main
}

echo "==> push consumer repo: /repo -> '$ORG/$REPO' main"
seed_repo /repo "$REPO" "Consumer repo: Order Events API (contract + backend + subscriber)"

echo "==> push Kafka consumer repo: /repo-kafka -> '$ORG/$KAFKA_REPO' main"
seed_repo /repo-kafka "$KAFKA_REPO" "Consumer repo: Order Events Kafka API (contract + backend + subscriber)"

echo "==> push governance repo: lean policy -> '$ORG/$GOV_REPO' main"
# The consumer CI only needs the policy (ruleset and the guidelines it
# encodes), so publish a lean repo rather than the whole governance context.
GOV_SRC=/tmp/gov-src
rm -rf "$GOV_SRC"; mkdir -p "$GOV_SRC"
# The async rules and the MQTT and Kafka rulesets that extend them.
cp /governance/spectral/asyncapi-*ruleset.yaml "$GOV_SRC"/
# functionsDir in the ruleset is relative, so the custom functions sit next to it.
cp -r /governance/spectral/spectral-functions "$GOV_SRC"/
# The async contract test runner the consumer CI calls.
cp -r /governance/contract-test "$GOV_SRC"/
# The broker policy generator and its check (the deployer runs as a service).
# Breaking change checks: structural diff and registry compatibility.
cp -r /governance/breaking-changes "$GOV_SRC"/
mkdir -p "$GOV_SRC"/broker-policy
cp /governance/broker-policy/*.js "$GOV_SRC"/broker-policy/
# Guidelines + their TechDocs wiring, at the repo root so Backstage discovers
# the api-guidelines Component and renders it as TechDocs.
cp /governance/api-guidelines/mkdocs.yml "$GOV_SRC"/
cp /governance/api-guidelines/catalog-info.yaml "$GOV_SRC"/
cp -r /governance/api-guidelines/docs "$GOV_SRC"/
seed_repo "$GOV_SRC" "$GOV_REPO" "Governance policy: AsyncAPI ruleset + guidelines"

echo "==> runner registration token -> /seed/runner-token"
docker exec -u git "$GITEA_CONTAINER" gitea actions generate-runner-token 2>/dev/null \
  | tr -d '\r\n' > /seed/runner-token
echo "    done"

echo "==> gitea seed complete"
