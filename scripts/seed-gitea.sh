#!/bin/sh
# Seeds a fresh Gitea so the demo has content: admin user, organization, repo,
# pushed code, and a runner registration token (written to the shared volume for
# gitea-runner to consume). Runs as the `gitea-seed` compose service after Gitea
# is healthy. Idempotent.
set -e

U="${GITEA_ADMIN_USER:-demo}"
P="${GITEA_ADMIN_PASSWORD:-demo12345}"
ORG="${GITEA_ORG:-governance-demo}"
# Consumer (product) repos, where PRs happen:
#   Orders the REST (OpenAPI) and the MQTT (AsyncAPI) contracts side by side,
#          one catalog-info, the backends (/repo = example/). Every demo step
#          is one PR here that governs both.
#   Kafka  the event API on Kafka, with the full pipeline (/repo-kafka = example-kafka/)
REPO="${GITEA_REPO:-devops-api-governance}"
KAFKA_REPO="${GITEA_KAFKA_REPO:-order-events-kafka-api}"
# Central governance repo: rulesets, custom functions, gate scripts and the
# guidelines, for REST and events. The consumers' CI clones this (a link, not
# a vendored copy). Source: /governance.
GOV_REPO="${GITEA_GOV_REPO:-api-governance}"
API="http://gitea:3000/api/v1"

echo "==> admin user '$U'"
docker exec -u git gitea gitea admin user create \
  --admin --username "$U" --password "$P" --email "$U@example.com" \
  --must-change-password=false 2>/dev/null || echo "    already exists"

echo "==> organization '$ORG'"
curl -sf -o /dev/null -u "$U:$P" -X POST -H 'Content-Type: application/json' \
  -d "{\"username\":\"$ORG\"}" "$API/orgs" || echo "    already exists"

# Earlier versions kept the MQTT API in a repo of its own. Its catalog entry
# would clash with the one in the orders repo, so drop it (generated content).
curl -sf -o /dev/null -u "$U:$P" -X DELETE "$API/repos/$ORG/order-events-api" \
  && echo "==> removed the old '$ORG/order-events-api' repo (now part of '$REPO')" || true

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
seed_repo /repo "$REPO" "Consumer repo: Orders API and Order Events API (contracts + backends)"

echo "==> push Kafka consumer repo: /repo-kafka -> '$ORG/$KAFKA_REPO' main"
seed_repo /repo-kafka "$KAFKA_REPO" "Consumer repo: Order Events Kafka API (contract + backend + subscriber)"

echo "==> push governance repo: lean policy -> '$ORG/$GOV_REPO' main"
# The consumers' CI only needs the policy, so publish a lean repo rather than
# the whole governance context (scripts/governance-bundle.sh picks the files).
sh /scripts/governance-bundle.sh /governance /tmp/gov-src
seed_repo /tmp/gov-src "$GOV_REPO" "Governance policy: rulesets, gate scripts and guidelines"

# Both consumer repos now hold their PR gates on main: a red PR must not be
# mergeable, not even by the admin. The admin may still (force-)push main, as
# this seed and `demo goto` do. `demo` re-applies this per step
# (scripts/demo/prep-stage.sh, protect_main).
for r in "$REPO" "$KAFKA_REPO"; do
  echo "==> protect '$ORG/$r' main: merge needs green checks"
  curl -sf -o /dev/null -u "$U:$P" -X DELETE "$API/repos/$ORG/$r/branch_protections/main" || true
  curl -sf -o /dev/null -u "$U:$P" -X POST -H 'Content-Type: application/json' -d "{
    \"rule_name\": \"main\",
    \"enable_push\": true, \"enable_push_whitelist\": true, \"push_whitelist_usernames\": [\"$U\"],
    \"enable_force_push\": true, \"enable_force_push_allowlist\": true, \"force_push_allowlist_usernames\": [\"$U\"],
    \"enable_status_check\": true, \"status_check_contexts\": [],
    \"block_admin_merge_override\": true
  }" "$API/repos/$ORG/$r/branch_protections" || echo "    could not protect $r main"
done

echo "==> runner registration token -> /seed/runner-token"
docker exec -u git gitea gitea actions generate-runner-token 2>/dev/null \
  | tr -d '\r\n' > /seed/runner-token
echo "    done"

echo "==> gitea seed complete"
