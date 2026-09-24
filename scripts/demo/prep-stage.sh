#!/bin/bash
# Off-camera prep for the recorded demo (presentation/screenplay.md).
# Pushes each stage's ready-made branch to the seeded Gitea repo, so nothing
# has to be authored live, and rolls Gitea + Backstage back to the start of
# any stage for a retake. Run from anywhere on the host, stack already up.
#
# Branches to push (each is what you check out on camera):
#   prep-stage.sh stage1           feat/add-orders-contract
#   prep-stage.sh stage2           feat/add-spectral-gate
#   prep-stage.sh stage2-red       feat/orders-server-url
#   prep-stage.sh stage3           feat/add-contract-test-gate
#   prep-stage.sh stage3-red       feat/orders-currency
#   prep-stage.sh stage4           feat/add-gateway-gate
#   prep-stage.sh stage5           feat/add-backwards-compat-gate
#   prep-stage.sh stage5-red       feat/orders-require-channel
#
# Rollback: put Gitea main + Backstage in the state right BEFORE a step is
# recorded. Closes open PRs and deletes feat/* branches. Afterwards make a
# fresh clone (main is force-pushed) and run the step's prep command.
#   prep-stage.sh goto 1           start of stage 1 (nothing merged; same as reset)
#   prep-stage.sh goto 2           start of stage 2 part 1 (stage 1 merged)
#   prep-stage.sh goto 2-red       start of stage 2 part 2 (spectral gate merged)
#   prep-stage.sh goto 3           start of stage 3 part 1 (stage 2 fully merged)
#   prep-stage.sh goto 3-red       start of stage 3 part 2 (contract-test gate merged)
#   prep-stage.sh goto 4           start of stage 4 (stage 3 fully merged)
#   prep-stage.sh goto 5           start of stage 5 part 1 (stage 4 merged)
#   prep-stage.sh goto 5-red       start of stage 5 part 2 (backwards-compat gate merged)
#   prep-stage.sh goto end         everything merged
#   prep-stage.sh reset            alias for: goto 1
#
#   prep-stage.sh refresh-catalog  make Backstage rescan Gitea now (a few seconds)
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
WF="$ROOT/scripts/demo/workflows"
CONTRACT="contracts/orders-openapi.yaml"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- the changes each stage makes; every one takes the repo dir as $1 --------

use_workflow() {  # $1 = repo dir, $2 = workflow file
  mkdir -p "$1/.gitea/workflows"
  cp "$2" "$1/.gitea/workflows/pr-governance.yml"
}

do_stage1() { cp -r "$ROOT/example/contracts" "$ROOT/example/catalog-info.yaml" "$1/"; }

do_stage2() { use_workflow "$1" "$WF/stage2-spectral.yml"; }
do_stage2_red() { sed -i 's#url: https://api.example.com#url: http://orders.example.com#' "$1/$CONTRACT"; }
do_stage2_fix() { sed -i 's#http://orders.example.com#https://orders.example.com#' "$1/$CONTRACT"; }

do_stage3() { use_workflow "$1" "$WF/stage3-contract-test.yml"; }
# The contract promises a field the running backend doesn't return.
do_stage3_red() {
  python3 - "$1/$CONTRACT" <<'EOF'
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
}
do_stage3_fix() { sed -i 's/required: \[orderId, isPaid, currency\]/required: [orderId, isPaid]/' "$1/$CONTRACT"; }

do_stage4() { use_workflow "$1" "$WF/stage4-gateway.yml"; }

do_stage5() { use_workflow "$1" "$ROOT/example/.gitea/workflows/pr-governance.yml"; }
do_stage5_red() {
  python3 - "$1/$CONTRACT" <<'EOF'
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
}
do_stage5_fix() { sed -i '/name: channel/,/required:/ s/required: true/required: false/' "$1/$CONTRACT"; }

# What lands on main, in order. "goto" replays the first N of these.
LAYERS=(
  "do_stage1"                       # 1  stage 1: contract + catalog entry
  "do_stage2"                       # 2  stage 2 part 1: spectral gate
  "do_stage2_red do_stage2_fix"     # 3  stage 2 part 2: http -> https fix merged
  "do_stage3"                       # 4  stage 3 part 1: contract-test gate
  "do_stage3_red do_stage3_fix"     # 5  stage 3 part 2: optional currency merged
  "do_stage4"                       # 6  stage 4: gateway gate
  "do_stage5"                       # 7  stage 5 part 1: backwards-compat gate
  "do_stage5_red do_stage5_fix"     # 8  stage 5 part 2: optional channel merged
)

layers_before() {
  case "$1" in
    1) echo 0 ;; 2) echo 1 ;; 2-red) echo 2 ;; 3) echo 3 ;; 3-red) echo 4 ;;
    4) echo 5 ;; 5) echo 6 ;; 5-red) echo 7 ;; end) echo 8 ;;
    *) return 1 ;;
  esac
}

# --- pushing branches ----------------------------------------------------------

gitc() { git -C "$WORK/repo" -c user.name="$U" -c user.email="$U@example.com" "$@"; }

# $1 = branch, $2 = commit message, $3.. = change functions to apply
make_branch() {
  local branch="$1" msg="$2"; shift 2
  git clone -q "$REMOTE" "$WORK/repo"
  gitc switch -q -c "$branch"
  for f in "$@"; do "$f" "$WORK/repo"; done
  gitc add -A
  gitc commit -q -m "$msg"
  gitc push -q -f origin HEAD
  echo "pushed $branch"
}

# --- rollback ------------------------------------------------------------------

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

# Close open PRs and delete leftover feat/* branches from earlier runs.
cleanup_gitea() {
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
}

# Consumer template minus contract, catalog entry and workflow, plus the first
# $1 layers, pushed as a fresh root commit onto Gitea main.
push_state() {
  local d="$WORK/base"
  rm -rf "$d"; mkdir -p "$d"
  cp -a "$ROOT/example/." "$d/"
  rm -rf "$d/contracts" "$d/catalog-info.yaml" "$d/.gitea"
  for ((i = 0; i < $1; i++)); do
    for f in ${LAYERS[$i]}; do "$f" "$d"; done
  done
  git -C "$d" init -q
  git -C "$d" -c user.name=seed -c user.email=seed@example.com add -A
  git -C "$d" -c user.name=seed -c user.email=seed@example.com commit -q -m "Consumer repo: Sample Orders API"
  git -C "$d" push -q -f "$REMOTE" HEAD:main
  echo "pushed state with $1 of ${#LAYERS[@]} layers to $REPO main"
}

# Drop the catalog entities this repo registered (API, Component, Group).
delete_repo_entities() {
  local t; t="$(backstage_token)"
  for uid in $(curl -sf -H "Authorization: Bearer $t" "http://localhost:7007/api/catalog/entities" \
      | python3 -c "import json,sys; print(' '.join(e['metadata']['uid'] for e in json.load(sys.stdin) if '/$REPO/' in e['metadata'].get('annotations',{}).get('backstage.io/managed-by-location','')))"); do
    curl -sf -o /dev/null -X DELETE -H "Authorization: Bearer $t" "http://localhost:7007/api/catalog/entities/by-uid/$uid"
    echo "deleted catalog entity $uid"
  done
}

# Never `podman start/restart backstage` (or `podman-compose up`): it starts its
# dependency gitea-seed, which force-pushes the full repo over Gitea main and
# wipes the stage state. Instead, trigger the Gitea provider's scheduled task
# through the catalog's scheduler endpoint: it rescans Gitea in a few seconds.
trigger_refresh() {
  local t; t="$(backstage_token)"
  curl -sf -o /dev/null -X POST -H "Authorization: Bearer $t" \
    "http://localhost:7007/api/catalog/.backstage/scheduler/v1/tasks/gitea-provider:local:refresh/trigger" \
    || echo "warning: could not trigger the Backstage refresh" >&2
}

catalog_has_api() {
  local t; t="$(backstage_token)" || return 1
  curl -sf -H "Authorization: Bearer $t" "http://localhost:7007/api/catalog/entities?filter=kind=api" \
    | python3 -c "import json,sys; sys.exit(0 if any(e['metadata']['name']=='sample-orders-api' for e in json.load(sys.stdin)) else 1)"
}

wait_for_api() {  # $1 = attempts, 3s apart
  for ((n = 1; n <= $1; n++)); do
    catalog_has_api && return 0
    sleep 3
  done
  return 1
}

refresh_catalog() {
  trigger_refresh
  if wait_for_api 15; then
    echo "backstage lists sample-orders-api"
  else
    echo "sample-orders-api not listed yet (is catalog-info.yaml on Gitea main?)"
  fi
}

goto() {
  local target="${1:-}" k
  k="$(layers_before "$target")" || { echo "unknown target '$target'; see the usage at the top of $0" >&2; exit 1; }
  cleanup_gitea
  push_state "$k"
  sync_governance_repo
  delete_repo_entities
  trigger_refresh
  if [ "$k" -ge 1 ]; then
    # Stage 1 is already merged in this state, so Backstage must list the API.
    wait_for_api 40 || { echo "sample-orders-api never appeared in Backstage" >&2; exit 1; }
    echo "backstage lists sample-orders-api"
  fi
  echo "ready: start of '$target'. Make a fresh clone (main was force-pushed), then run this stage's prep command."
}

case "${1:-}" in
  goto) goto "${2:-}" ;;
  reset) goto 1 ;;
  refresh-catalog) refresh_catalog ;;
  stage1)     make_branch feat/add-orders-contract "Add Orders API contract and register it in the catalog" do_stage1 ;;
  stage2)     make_branch feat/add-spectral-gate "Add spectral-openapi-check gate" do_stage2 ;;
  stage2-red) make_branch feat/orders-server-url "Move Orders API to orders.example.com" do_stage2_red ;;
  stage3)     make_branch feat/add-contract-test-gate "Add contract-test gate (Microcks)" do_stage3 ;;
  stage3-red) make_branch feat/orders-currency "Add currency to the order response" do_stage3_red ;;
  stage4)     make_branch feat/add-gateway-gate "Add gateway-deploy-check gate (KrakenD)" do_stage4 ;;
  stage5)     make_branch feat/add-backwards-compat-gate "Insert breaking-changes-check between lint and contract-test" do_stage5 ;;
  stage5-red) make_branch feat/orders-require-channel "Require sales channel when reading an order" do_stage5_red ;;
  *) sed -n '2,34p' "$0"; exit 1 ;;
esac
