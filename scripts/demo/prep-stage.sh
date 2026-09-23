#!/bin/bash
# Off-camera prep for the recorded demo (presentation/screenplay.md).
# Pushes each stage's ready-made branch to the seeded Gitea repo, so nothing
# has to be authored live. Run from anywhere on the host, stack already up.
#
#   prep-stage.sh reset            Gitea main -> Stage 1 starting state
#   prep-stage.sh stage1           feat/add-orders-contract
#   prep-stage.sh stage2           feat/add-spectral-gate
#   prep-stage.sh stage2-red       feat/orders-server-url     (after stage2 is merged)
#   prep-stage.sh stage3           feat/add-contract-test-gate
#   prep-stage.sh stage3-red       feat/orders-currency       (after stage3 is merged)
#   prep-stage.sh stage4           feat/add-gateway-gate
#   prep-stage.sh stage5           feat/add-backwards-compat-gate
#   prep-stage.sh stage5-red       feat/orders-require-channel (after stage5 is merged)
#   prep-stage.sh refresh-catalog  force Backstage to rescan Gitea now
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
U="${GITEA_ADMIN_USER:-demo}"
P="${GITEA_ADMIN_PASSWORD:-demo12345}"
GITEA="http://localhost:3000"
ORG="governance-demo"
REPO="devops-api-governance"
GOV_REPO="api-governance"
API="$GITEA/api/v1"
REMOTE="http://$U:$P@localhost:3000/$ORG/$REPO.git"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

gitc() { git -C "$WORK/repo" -c user.name="$U" -c user.email="$U@example.com" "$@"; }

# Fresh clone of Gitea main on a new branch; caller applies the change.
branch_from_main() {
  git clone -q "$REMOTE" "$WORK/repo"
  gitc switch -q -c "$1"
}
commit_and_push() {
  gitc add -A
  gitc commit -q -m "$1"
  gitc push -q -f origin HEAD
  echo "pushed $(gitc rev-parse --abbrev-ref HEAD)"
}

use_workflow() {
  mkdir -p "$WORK/repo/.gitea/workflows"
  cp "$1" "$WORK/repo/.gitea/workflows/pr-governance.yml"
}

# Same lean policy repo gitea-seed publishes, from this working tree.
sync_governance_repo() {
  local g="$WORK/gov"
  mkdir -p "$g/gateway"
  cp "$ROOT/governance/spectral/spectral-ruleset.yaml" "$g/"
  cp -r "$ROOT/governance/spectral/spectral-functions" "$g/"
  cp "$ROOT/governance/api-guidelines/mkdocs.yml" "$ROOT/governance/api-guidelines/catalog-info.yaml" "$g/"
  cp -r "$ROOT/governance/api-guidelines/docs" "$g/"
  cp "$ROOT/governance/gateway/generate.js" "$ROOT/governance/gateway/package.json" \
     "$ROOT/governance/gateway/krakend-base.json" "$g/gateway/"
  git -C "$g" init -q
  git -C "$g" -c user.name=seed -c user.email=seed@example.com add -A
  git -C "$g" -c user.name=seed -c user.email=seed@example.com commit -q -m "Governance policy: Spectral ruleset + functions"
  git -C "$g" push -q -f "http://$U:$P@localhost:3000/$ORG/$GOV_REPO.git" HEAD:main
  echo "synced $GOV_REPO"
}

backstage_token() {
  curl -sf -X POST "http://localhost:7007/api/auth/guest/refresh" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['backstageIdentity']['token'])"
}

reset() {
  # Close open PRs and delete leftover feat/* branches from earlier runs.
  for n in $(curl -sf -u "$U:$P" "$API/repos/$ORG/$REPO/pulls?state=open&limit=50" \
      | python3 -c "import json,sys; print(' '.join(str(p['number']) for p in json.load(sys.stdin)))"); do
    curl -sf -o /dev/null -u "$U:$P" -X PATCH -H 'Content-Type: application/json' \
      -d '{"state":"closed"}' "$API/repos/$ORG/$REPO/pulls/$n"
    echo "closed PR #$n"
  done
  for b in $(curl -sf -u "$U:$P" "$API/repos/$ORG/$REPO/branches?limit=100" \
      | python3 -c "import json,sys; print(' '.join(b['name'] for b in json.load(sys.stdin) if b['name'].startswith('feat/')))"); do
    curl -sf -o /dev/null -u "$U:$P" -X DELETE "$API/repos/$ORG/$REPO/branches/$b"
    echo "deleted branch $b"
  done

  # Stage 1 starting state: the consumer template minus contract, catalog
  # entry and workflow.
  mkdir -p "$WORK/base"
  cp -a "$ROOT/example/." "$WORK/base/"
  rm -rf "$WORK/base/contracts" "$WORK/base/catalog-info.yaml" "$WORK/base/.gitea"
  git -C "$WORK/base" init -q
  git -C "$WORK/base" -c user.name=seed -c user.email=seed@example.com add -A
  git -C "$WORK/base" -c user.name=seed -c user.email=seed@example.com commit -q -m "Consumer repo: Sample Orders API (backend only)"
  git -C "$WORK/base" push -q -f "$REMOTE" HEAD:main
  echo "reset $REPO main"

  sync_governance_repo

  # Drop the catalog entities this repo registered (API, Component, Group).
  local t; t="$(backstage_token)"
  for uid in $(curl -sf -H "Authorization: Bearer $t" "http://localhost:7007/api/catalog/entities" \
      | python3 -c "import json,sys; print(' '.join(e['metadata']['uid'] for e in json.load(sys.stdin) if '/$REPO/' in e['metadata'].get('annotations',{}).get('backstage.io/managed-by-location','')))"); do
    curl -sf -o /dev/null -X DELETE -H "Authorization: Bearer $t" "http://localhost:7007/api/catalog/entities/by-uid/$uid"
    echo "deleted catalog entity $uid"
  done
}

# stop+start, not restart/recreate: restart trips a dependency check on the
# exited gitea-seed container, and podman-compose recreate re-runs gitea-seed,
# which force-pushes the full repo over Gitea main.
refresh_catalog() {
  podman stop backstage >/dev/null && podman start backstage >/dev/null
  for i in $(seq 1 60); do
    curl -sf -o /dev/null http://localhost:7007 && { echo "backstage up"; return; }
    sleep 2
  done
  echo "backstage did not come back" >&2; exit 1
}

case "${1:-}" in
  reset) reset ;;
  refresh-catalog) refresh_catalog ;;
  stage1)
    branch_from_main feat/add-orders-contract
    cp -r "$ROOT/example/contracts" "$ROOT/example/catalog-info.yaml" "$WORK/repo/"
    commit_and_push "Add Orders API contract and register it in the catalog" ;;
  stage2)
    branch_from_main feat/add-spectral-gate
    use_workflow "$ROOT/scripts/demo/workflows/stage2-spectral.yml"
    commit_and_push "Add spectral-openapi-check gate" ;;
  stage2-red)
    branch_from_main feat/orders-server-url
    sed -i 's#url: https://api.example.com#url: http://orders.example.com#' "$WORK/repo/contracts/orders-openapi.yaml"
    commit_and_push "Move Orders API to orders.example.com" ;;
  stage3)
    branch_from_main feat/add-contract-test-gate
    use_workflow "$ROOT/scripts/demo/workflows/stage3-contract-test.yml"
    commit_and_push "Add contract-test gate (Microcks)" ;;
  stage3-red)
    # The contract promises a field the running backend doesn't return.
    branch_from_main feat/orders-currency
    python3 - "$WORK/repo/contracts/orders-openapi.yaml" <<'EOF'
import sys
p = sys.argv[1]
lines = open(p).read().split('\n')
def insert_after(line, new):
    i = lines.index(line) + 1
    lines[i:i] = new
insert_after('                    isPaid: true', ['                    currency: PLN'])
i = lines.index('                  isPaid:')
assert lines[i + 1] == '                    type: boolean'
lines[i + 2:i + 2] = [
    '                  currency:',
    '                    type: string',
    '                    description: ISO 4217 code of the order total.',
]
insert_after('                type: object', ['                required: [orderId, isPaid, currency]'])
open(p, 'w').write('\n'.join(lines))
EOF
    commit_and_push "Add currency to the order response" ;;
  stage4)
    branch_from_main feat/add-gateway-gate
    use_workflow "$ROOT/scripts/demo/workflows/stage4-gateway.yml"
    commit_and_push "Add gateway-deploy-check gate (KrakenD)" ;;
  stage5)
    branch_from_main feat/add-backwards-compat-gate
    use_workflow "$ROOT/example/.gitea/workflows/pr-governance.yml"
    commit_and_push "Insert breaking-changes-check between lint and contract-test" ;;
  stage5-red)
    branch_from_main feat/orders-require-channel
    python3 - "$WORK/repo/contracts/orders-openapi.yaml" <<'EOF'
import sys
p = sys.argv[1]
lines = open(p).read().split('\n')
i = lines.index('      responses:')
lines[i:i] = [
    '        - name: channel',
    '          in: query',
    '          required: true',
    '          description: Sales channel the order is read from.',
    '          schema:',
    '            type: string',
]
open(p, 'w').write('\n'.join(lines))
EOF
    commit_and_push "Require sales channel when reading an order" ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac
