#!/bin/bash
# Off-camera prep for the recorded demo (presentation/screenplay.md).
# Prepares each stage's ready-made branch in the demo clone, so nothing has to
# be authored live, and rolls Gitea, Backstage and the gateway back to the start
# of any stage for a retake. Run from anywhere on the host, stack already up.
#
# During a recording you only need one command, run after each merge:
#   prep-stage.sh next             work out the next step from Gitea main and
#                                  prepare its branch (says what to do if it is
#                                  already prepared or still waiting for a merge)
#   prep-stage.sh status           the same, without preparing anything
#   prep-stage.sh preflight        read-only "ready to record?" check of stack, Gitea,
#                                  Backstage, gateway, mock and demo clone
#
# Branches to prepare. Each one is created ONLY in the demo clone ($DEMO_CLONE,
# default ~/demo/orders-api), committed on top of the current Gitea main and NOT
# pushed: on camera you switch to it, show the diff and push it yourself. The
# command fetches, updates the clone's local main and adds the branch without
# touching what is checked out, so it is safe to run while the recording
# terminal sits in the clone.
#   prep-stage.sh stage1           feat/add-catalog-entry
#   prep-stage.sh stage2           feat/add-spectral-gate
#   prep-stage.sh stage2-red       feat/orders-server-url     (after stage2 is merged)
#   prep-stage.sh stage3           feat/add-contract-test-gate
#   prep-stage.sh stage3-red       feat/orders-currency       (after stage3 is merged)
#   prep-stage.sh stage4           feat/add-gateway-gate
#   prep-stage.sh stage5           feat/add-backwards-compat-gate
#   prep-stage.sh stage5-red       feat/orders-require-channel (after stage5 is merged)
#
# Rollback: put Gitea main, Backstage and the KrakenD gateway in the state right
# BEFORE a step is recorded (closes open PRs, deletes all feat/* branches on Gitea),
# make a fresh demo clone and prepare that step's branch in it. cd into the clone
# again if your terminal was inside the old one.
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
RD="$ROOT/scripts/demo/readmes"   # the repo README as it reads at each stage
CONTRACT="contracts/orders-openapi.yaml"
DEMO_CLONE="${DEMO_CLONE:-$HOME/demo/orders-api}"   # the clone you record in
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- the changes each stage makes; every one takes the repo dir as $1 --------

use_workflow() {  # $1 = repo dir, $2 = workflow file
  mkdir -p "$1/.gitea/workflows"
  cp "$2" "$1/.gitea/workflows/pr-governance.yml"
}

use_readme() { cp "$2" "$1/README.md"; }  # $1 = repo dir, $2 = README file

do_stage1() {
  cp "$ROOT/example/catalog-info.yaml" "$1/"
  use_readme "$1" "$RD/stage1.md"
}

do_stage2() { use_workflow "$1" "$WF/stage2-spectral.yml"; use_readme "$1" "$RD/stage2.md"; }
do_stage2_red() { sed -i 's#url: https://api.api-peak.com#url: http://orders.api-peak.com#' "$1/$CONTRACT"; }
do_stage2_fix() { sed -i 's#http://orders.api-peak.com#https://orders.api-peak.com#' "$1/$CONTRACT"; }

do_stage3() { use_workflow "$1" "$WF/stage3-contract-test.yml"; use_readme "$1" "$RD/stage3.md"; }
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

do_stage4() { use_workflow "$1" "$WF/stage4-gateway.yml"; use_readme "$1" "$RD/stage4.md"; }

do_stage5() { use_workflow "$1" "$ROOT/example/.gitea/workflows/pr-governance.yml"; use_readme "$1" "$ROOT/example/README.md"; }
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
  "do_stage1"                       # 1  stage 1: catalog entry
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

# CI runs still going (from an abandoned take) keep going after their PR is
# closed: a late gateway-deploy-check would redeploy KrakenD and a late
# contract-test would reload the Microcks mock after goto has reset them.
ci_active_runs() {
  curl -sf -u "$U:$P" "$API/repos/$ORG/$REPO/actions/runs?limit=20" \
    | python3 -c "import json,sys; print(sum(r['status'] != 'completed' for r in json.load(sys.stdin)['workflow_runs']))"
}
wait_for_idle_ci() {
  local n i
  for ((i = 1; i <= 90; i++)); do
    n="$(ci_active_runs)"
    [ "$n" = 0 ] && return 0
    [ "$i" = 1 ] && echo "waiting for $n CI run(s) from an earlier take to finish (up to 3 min)..."
    sleep 2
  done
  echo "CI is still busy after 3 min; check $GITEA/$ORG/$REPO/actions" >&2; exit 1
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

# $1 = dir, $2 = layers: the consumer template minus the catalog entry and the
# workflow (backend + contract remain), plus the first $2 layers.
build_state() {
  local d="$1" i f
  rm -rf "$d"; mkdir -p "$d"
  cp -a "$ROOT/example/." "$d/"
  rm -rf "$d/catalog-info.yaml" "$d/.gitea"
  use_readme "$d" "$RD/stage0.md"
  for ((i = 0; i < $2; i++)); do
    for f in ${LAYERS[$i]}; do "$f" "$d"; done
  done
}

# The state with the first $1 layers, pushed as a fresh root commit onto Gitea main.
push_state() {
  local d="$WORK/base"
  build_state "$d" "$1"
  git -C "$d" init -q
  git -C "$d" -c user.name=seed -c user.email=seed@example.com add -A
  git -C "$d" -c user.name=seed -c user.email=seed@example.com commit -q -m "Consumer repo: Orders API"
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

# Microcks serves the last contract imported under the "Orders API" name as a
# mock, so load the state's contract: the mock then matches what is merged.
sync_microcks() {
  curl -sf -o /dev/null -X POST -F "file=@$WORK/base/$CONTRACT" \
    "http://localhost:8080/api/artifact/upload?mainArtifact=true" \
    || { echo "could not load the contract into Microcks" >&2; exit 1; }
  echo "microcks mock matches the state's contract"
}

# TechDocs builds a page the first time it is opened (a "building" banner on
# camera). The governance repo was just re-pushed, so build it now.
prewarm_techdocs() {
  local t; t="$(backstage_token)"
  curl -s -N --max-time 240 -H "Authorization: Bearer $t" -H "Accept: text/event-stream" \
    "http://localhost:7007/api/techdocs/sync/default/component/api-guidelines" | grep >/dev/null -c "^event: finish" \
    && echo "api guidelines (TechDocs) built" \
    || echo "warning: TechDocs build did not finish; open the guidelines once before recording" >&2
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
    | python3 -c "import json,sys; sys.exit(0 if any(e['metadata']['name']=='orders-api' for e in json.load(sys.stdin)) else 1)"
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
    echo "backstage lists orders-api"
  else
    echo "orders-api not listed yet (is catalog-info.yaml on Gitea main?)"
  fi
}

# KrakenD keeps the config CI last deployed, so it must be put back in step
# with the stage: until the gateway gate is merged the gateway has no routes
# (404); afterwards it serves the contract. Posts to the deployer sidecar,
# which writes the config and restarts krakend.
gateway_deploy() {  # $1 = krakend.json
  podman exec krakend-deployer wget -qO- --header 'Content-Type: application/json' \
    --post-data "$(cat "$1")" http://localhost:9000/deploy >/dev/null
  for i in $(seq 1 30); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8090/orders/1)" != 000 ] && return 0
    sleep 1
  done
  echo "gateway did not come back after the deploy" >&2; exit 1
}

# $1 = layers merged so far (layer 6 is the gateway gate); reads $WORK/base
sync_gateway() {
  if [ "$1" -ge 6 ]; then
    local g="$WORK/gw"
    mkdir -p "$g"
    cp "$ROOT/governance/gateway/generate.js" "$ROOT/governance/gateway/package.json" \
       "$ROOT/governance/gateway/krakend-base.json" "$g/"
    (cd "$g" && npm install --silent --no-audit --no-fund >/dev/null 2>&1)
    node "$g/generate.js" "$WORK/base/$CONTRACT" "$g/krakend.json" >/dev/null
    gateway_deploy "$g/krakend.json"
    [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8090/orders/123)" = 200 ] \
      || { echo "gateway should serve /orders/123 but doesn't" >&2; exit 1; }
    echo "gateway serves /orders/{orderId}"
  else
    gateway_deploy "$ROOT/governance/gateway/krakend-base.json"
    [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8090/orders/123)" = 404 ] \
      || { echo "gateway should have no routes yet but answers" >&2; exit 1; }
    echo "gateway has no routes yet (404)"
  fi
}

# Refuse to delete anything that is not a previous clone of the demo repo.
check_demo_clone() {
  [ -e "$DEMO_CLONE" ] || return 0
  case "$(git -C "$DEMO_CLONE" remote get-url origin 2>/dev/null)" in
    *"/$ORG/$REPO.git") ;;
    *) echo "refusing to replace $DEMO_CLONE: it is not a clone of $ORG/$REPO (move it away or set DEMO_CLONE)" >&2; exit 1 ;;
  esac
}

# A fresh clone of Gitea main at $DEMO_CLONE, the place the recording happens in.
fresh_demo_clone() {
  check_demo_clone
  rm -rf "$DEMO_CLONE"
  mkdir -p "$(dirname "$DEMO_CLONE")"
  git clone -q "$REMOTE" "$DEMO_CLONE"
  echo "demo clone ready: $DEMO_CLONE"
}

# Branch that exists only in the demo clone, committed on top of the current Gitea
# main but NOT pushed: the presenter pushes it on camera. Done in a temporary
# worktree, so whatever the recording terminal has checked out stays untouched.
# $1 = branch, $2 = commit message, $3.. = change functions.
make_local_branch() {
  local branch="$1" msg="$2"; shift 2
  local g=(git -C "$DEMO_CLONE") cur wt="$WORK/wt"
  [ -d "$DEMO_CLONE/.git" ] || fresh_demo_clone
  check_demo_clone
  if git ls-remote --exit-code "$REMOTE" "refs/heads/$branch" >/dev/null; then
    echo "Gitea already has branch $branch (from an earlier take). Run 'goto <target>' to reset, or delete that branch first." >&2
    exit 1
  fi
  "${g[@]}" fetch -q --prune origin
  # Bring the local main up to the Gitea main, without switching branches.
  cur="$("${g[@]}" branch --show-current)"
  if [ "$cur" = main ]; then
    "${g[@]}" merge -q --ff-only origin/main \
      || { echo "cannot fast-forward main in $DEMO_CLONE (local changes or commits on main?)" >&2; exit 1; }
  else
    "${g[@]}" branch -f main origin/main
  fi
  if "${g[@]}" show-ref --verify -q "refs/heads/$branch"; then
    [ "$cur" = "$branch" ] && { echo "$branch is checked out in $DEMO_CLONE; switch to main first" >&2; exit 1; }
    "${g[@]}" branch -q -D "$branch"
  fi
  "${g[@]}" worktree add -q -b "$branch" "$wt" origin/main
  for f in "$@"; do "$f" "$wt"; done
  git -C "$wt" add -A
  git -C "$wt" -c user.name="$U" -c user.email="$U@example.com" commit -q -m "$msg"
  "${g[@]}" worktree remove --force "$wt"
  echo "local branch $branch ready in $DEMO_CLONE (not pushed; main updated to Gitea main)"
}

# What each prep step prepares: the branch you check out on camera.
prep_step() {
  case "$1" in
    stage1)     make_local_branch feat/add-catalog-entry "Register the Orders API in the catalog" do_stage1 ;;
    stage2)     make_local_branch feat/add-spectral-gate "Add spectral-openapi-check gate" do_stage2 ;;
    stage2-red) make_local_branch feat/orders-server-url "Move Orders API to orders.api-peak.com" do_stage2_red ;;
    stage3)     make_local_branch feat/add-contract-test-gate "Add contract-test gate (Microcks)" do_stage3 ;;
    stage3-red) make_local_branch feat/orders-currency "Add currency to the order response" do_stage3_red ;;
    stage4)     make_local_branch feat/add-gateway-gate "Add gateway-deploy-check gate (KrakenD)" do_stage4 ;;
    stage5)     make_local_branch feat/add-backwards-compat-gate "Insert breaking-changes-check between lint and contract-test" do_stage5 ;;
    stage5-red) make_local_branch feat/orders-require-channel "Require sales channel when reading an order" do_stage5_red ;;
    *) return 1 ;;
  esac
}

# How many layers Gitea main holds: compare it with every replayed state.
detect_layers() {
  local cur="$WORK/cur" k
  rm -rf "$cur"; git clone -q "$REMOTE" "$cur"; rm -rf "$cur/.git"
  for ((k = 0; k <= ${#LAYERS[@]}; k++)); do
    build_state "$WORK/st" "$k"
    diff -rq "$cur" "$WORK/st" >/dev/null 2>&1 && { echo "$k"; return 0; }
  done
  return 1
}

# The step recorded after $1 layers are merged, and the branch it uses.
step_after() {
  local steps=(stage1 stage2 stage2-red stage3 stage3-red stage4 stage5 stage5-red "")
  echo "${steps[$1]}"
}
branch_of() {
  case "$1" in
    stage1) echo feat/add-catalog-entry ;;         stage2) echo feat/add-spectral-gate ;;
    stage2-red) echo feat/orders-server-url ;;     stage3) echo feat/add-contract-test-gate ;;
    stage3-red) echo feat/orders-currency ;;       stage4) echo feat/add-gateway-gate ;;
    stage5) echo feat/add-backwards-compat-gate ;; stage5-red) echo feat/orders-require-channel ;;
  esac
}

# Work out where the demo is and prepare the next branch (or just report it).
next_step() {  # $1 = "prepare" or "status"
  local k step branch
  k="$(detect_layers)" || {
    echo "Gitea main matches no demo state (after podman-compose up, or a half-done step?). Use: $0 goto <target>" >&2
    exit 1
  }
  step="$(step_after "$k")"
  echo "Gitea main: $k of ${#LAYERS[@]} steps merged."
  if [ -z "$step" ]; then echo "Everything is merged; nothing left to record."; return 0; fi
  branch="$(branch_of "$step")"
  echo "Next: $step, branch $branch."
  if git ls-remote --exit-code "$REMOTE" "refs/heads/$branch" >/dev/null; then
    echo "$branch is already on Gitea: open (or finish) its PR and merge it; then run next again."
  elif [ -d "$DEMO_CLONE/.git" ] && git -C "$DEMO_CLONE" show-ref --verify -q "refs/heads/$branch"; then
    echo "$branch is already prepared in $DEMO_CLONE: git switch $branch"
  elif [ "$1" = prepare ]; then
    prep_step "$step"
  fi
}

# Read-only "ready to record?" check against whatever state Gitea main is in.
preflight() {
  local problems=0 k step branch t names foreign want
  pass() { echo "  ok       $*"; }
  miss() { echo "  PROBLEM  $*"; problems=$((problems + 1)); }
  code() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

  echo "Stack"
  names="$(podman ps --format '{{.Names}}')"
  for c in gitea backend microcks-uber krakend-deployer gitea-runner backstage krakend; do
    grep -qx "$c" <<<"$names" && pass "container $c running" || miss "container $c not running (podman-compose up, then goto 1)"
  done
  foreign="$(podman ps --format '{{index .Labels "com.docker.compose.project"}} {{.Names}}' | awk '$1 != "devops-api-governance" {print $2}' | tr '\n' ' ')"
  [ -z "$foreign" ] && pass "no containers from other projects" || miss "other containers running: $foreign(ports may clash)"
  for u in http://localhost:3000/api/healthz http://localhost:8080/api/health http://localhost:8081/health http://localhost:7007; do
    [ "$(code "$u")" = 200 ] && pass "$u answers" || miss "$u does not answer"
  done
  podman logs gitea-runner 2>&1 | grep >/dev/null -c "declare successfully" && pass "CI runner registered" || miss "CI runner not registered"
  podman image exists localhost/devops-api-governance-ci:latest && pass "CI image present (CI runs offline)" || miss "CI image missing (podman-compose up builds it)"

  echo "Demo state"
  if ! k="$(detect_layers)"; then
    miss "Gitea main matches no demo state: run goto 1 (or goto <target>)"
    echo; echo "NOT READY: $problems problem(s)"; return 1
  fi
  step="$(step_after "$k")"; branch="$(branch_of "$step")"
  pass "Gitea main: $k of ${#LAYERS[@]} steps merged; next: ${step:-nothing (all merged)}"
  [ "$(ci_active_runs)" = 0 ] && pass "no CI running" || miss "CI is still running (an earlier take?): wait for it, then goto <target>"
  [ "$(curl -sf -u "$U:$P" "$API/repos/$ORG/$REPO/pulls?state=open" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')" = 0 ] \
    && pass "no open PRs" || miss "open PRs on Gitea: merge or close them (goto closes them)"
  if [ -n "$branch" ] && git ls-remote --exit-code "$REMOTE" "refs/heads/$branch" >/dev/null; then
    miss "$branch is already on Gitea (half-done step?): finish its PR, or goto"
  fi
  if catalog_has_api; then
    [ "$k" -ge 1 ] && pass "Backstage lists orders-api" || miss "Backstage lists orders-api before Stage 1 is merged: goto 1"
  else
    [ "$k" -ge 1 ] && miss "Backstage does not list orders-api yet: refresh-catalog" || pass "Backstage lists no API yet (Stage 1 before)"
  fi
  if [ "$k" -ge 6 ]; then want=200; else want=404; fi
  [ "$(code http://localhost:8090/orders/123)" = "$want" ] && pass "gateway answers $want (as it should at this point)" || miss "gateway does not answer $want: goto <target> resets it"
  build_state "$WORK/pf" "$k"
  if python3 - "$WORK/pf/$CONTRACT" "$(curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123)" <<'PY'
import json, sys, yaml
c = yaml.safe_load(open(sys.argv[1]))
ex = c['paths']['/orders/{orderId}']['get']['responses']['200']['content']['application/json']['examples']['order_123']['value']
sys.exit(0 if json.loads(sys.argv[2] or 'null') == ex else 1)
PY
  then pass "Microcks mock matches the merged contract"; else miss "Microcks mock differs from the merged contract: goto <target> reloads it"; fi
  t="$(backstage_token)"
  curl -sf -H "Authorization: Bearer $t" "http://localhost:7007/api/techdocs/static/docs/default/component/api-guidelines/index.html" \
    | grep >/dev/null -c 'id="https-api-peakrest172025-https"' && pass "API guidelines page built in Backstage" || miss "API guidelines page not built: goto builds it"

  echo "Demo clone ($DEMO_CLONE)"
  if [ ! -d "$DEMO_CLONE/.git" ]; then
    miss "no demo clone: goto <target> creates it"
  else
    local g=(git -C "$DEMO_CLONE") cur
    [ -z "$("${g[@]}" status --porcelain)" ] && pass "no uncommitted changes" || miss "uncommitted changes in the clone"
    cur="$("${g[@]}" branch --show-current)"
    [ "$cur" = main ] && pass "on main" || echo "  note     on $cur (fine if you are mid-stage)"
    [ "$("${g[@]}" rev-parse main)" = "$(git ls-remote "$REMOTE" refs/heads/main | cut -f1)" ] \
      && pass "local main = Gitea main" || miss "local main differs from Gitea main: run next (updates it) or goto"
    if [ -n "$branch" ]; then
      "${g[@]}" show-ref --verify -q "refs/heads/$branch" && pass "next branch $branch prepared" || miss "next branch $branch not prepared: run next"
    fi
  fi

  echo
  if [ "$problems" = 0 ]; then
    echo "READY: record ${step:-nothing left (all merged)}${branch:+ (git switch $branch)}."
    echo "Not checked here: that the browser is signed in to Gitea as demo."
  else
    echo "NOT READY: $problems problem(s) above."; return 1
  fi
}

# The step that is recorded from each goto state.
step_at() {
  case "$1" in
    1) echo stage1 ;; 2) echo stage2 ;; 2-red) echo stage2-red ;; 3) echo stage3 ;;
    3-red) echo stage3-red ;; 4) echo stage4 ;; 5) echo stage5 ;; 5-red) echo stage5-red ;;
    *) echo "" ;;
  esac
}

goto() {
  local target="${1:-}" k
  k="$(layers_before "$target")" || { echo "unknown target '$target'; see the usage at the top of $0" >&2; exit 1; }
  check_demo_clone   # fail before changing anything
  wait_for_idle_ci
  cleanup_gitea
  push_state "$k"
  sync_governance_repo
  delete_repo_entities
  sync_gateway "$k"
  sync_microcks
  prewarm_techdocs
  trigger_refresh
  if [ "$k" -ge 1 ]; then
    # Stage 1 is already merged in this state, so Backstage must list the API.
    wait_for_api 40 || { echo "orders-api never appeared in Backstage" >&2; exit 1; }
    echo "backstage lists orders-api"
  fi
  fresh_demo_clone
  local step; step="$(step_at "$target")"
  [ -z "$step" ] || prep_step "$step"
  echo "ready: start of '$target'. Work in $DEMO_CLONE (cd there again if your terminal was inside the old clone)."
}

case "${1:-}" in
  goto) goto "${2:-}" ;;
  reset) goto 1 ;;
  next) next_step prepare ;;
  status) next_step status ;;
  preflight) preflight ;;
  refresh-catalog) refresh_catalog ;;
  stage1|stage2|stage2-red|stage3|stage3-red|stage4|stage5|stage5-red) prep_step "$1" ;;
  *) sed -n '2,45p' "$0"; exit 1 ;;
esac
