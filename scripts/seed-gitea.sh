#!/bin/sh
# Seeds a fresh Gitea so the demo has content: admin user, organization, repo,
# pushed code, and a runner registration token (written to the shared volume for
# gitea-runner to consume). Runs as the `gitea-seed` compose service after Gitea
# is healthy. Idempotent.
set -e

U="${GITEA_ADMIN_USER:-demo}"
P="${GITEA_ADMIN_PASSWORD:-demo12345}"
ORG="${GITEA_ORG:-governance-demo}"
# Consumer (product) repo — the OpenAPI contract + catalog-info + backend impl.
# This is where PRs happen. Source: /repo (the example/ template folder).
REPO="${GITEA_REPO:-devops-api-governance}"
# Central governance repo — the Spectral ruleset + custom functions. The
# consumer's CI clones this (a link, not a vendored copy). Source: /governance
# (the project root = governance context).
GOV_REPO="${GITEA_GOV_REPO:-api-governance}"
API="http://gitea:3000/api/v1"

echo "==> admin user '$U'"
docker exec -u git gitea gitea admin user create \
  --admin --username "$U" --password "$P" --email "$U@example.com" \
  --must-change-password=false 2>/dev/null || echo "    already exists"

echo "==> organization '$ORG'"
curl -sf -o /dev/null -u "$U:$P" -X POST -H 'Content-Type: application/json' \
  -d "{\"username\":\"$ORG\"}" "$API/orgs" || echo "    already exists"

for r in "$REPO" "$GOV_REPO"; do
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
seed_repo /repo "$REPO" "Consumer repo: Sample Orders API (contract + backend)"

echo "==> push governance repo: lean policy -> '$ORG/$GOV_REPO' main"
# The consumer CI only needs the policy (ruleset + custom functions + the
# guidelines they encode), so publish a lean repo rather than the whole
# governance context. Source of truth stays in governance/spectral.
GOV_SRC=/tmp/gov-src
rm -rf "$GOV_SRC"; mkdir -p "$GOV_SRC"
cp /governance/spectral/spectral-ruleset.yaml "$GOV_SRC"/
cp -r /governance/spectral/spectral-functions "$GOV_SRC"/
cp /governance/api-guidelines.md "$GOV_SRC"/ 2>/dev/null || true
seed_repo "$GOV_SRC" "$GOV_REPO" "Governance policy: Spectral ruleset + functions"

echo "==> runner registration token -> /seed/runner-token"
docker exec -u git gitea gitea actions generate-runner-token 2>/dev/null \
  | tr -d '\r\n' > /seed/runner-token
echo "    done"

echo "==> gitea seed complete"
