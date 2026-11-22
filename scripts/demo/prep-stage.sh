#!/bin/bash
# Off-camera prep for the recorded demo (presentation/screenplay.md).
# One demo for REST and events: the orders repo holds the Orders API (OpenAPI)
# and the Order Events API (AsyncAPI on MQTT) side by side, and every step is
# ONE pull request that adds the same gate, or the same kind of change, to
# both. Prepares each step's ready-made branch in the demo clone, so nothing
# has to be authored live, and rolls Gitea, Backstage, the gateway, Microcks,
# the schema registry and the broker policy back to the start of any step for
# a retake. Run from anywhere on the host, stack already up (profiles
# contract, catalog, gateway, events; kafka for the Kafka steps).
#
# During a recording you only need one command, run after each merge:
#   prep-stage.sh next             work out the next step from Gitea main and
#                                  prepare its branch (says what to do if it is
#                                  already prepared or still waiting for a merge)
#   prep-stage.sh status           the same, without preparing anything
#   prep-stage.sh preflight        read-only "ready to record?" check
#   prep-stage.sh deny             the broker refusing what the policy does not grant
#
# Steps, in talk order. Each branch is created ONLY in the demo clone
# ($DEMO_CLONE, default ~/demo/orders-api; the Kafka steps in
# $DEMO_KAFKA_CLONE, default ~/demo/order-events-kafka-api), committed on top
# of the current Gitea main and NOT pushed: on camera you switch to it, show
# the diff and push it yourself.
#   stage1      feat/add-catalog-entry           catalog-info.yaml: Backstage lists both APIs
#   stage2      feat/add-lint-gates              PR workflows: OpenLint (REST), asyncapi-lint (events)
#   stage2-red  feat/orders-server-and-paid-at   http:// server URL and snake_case paid_at: red;
#                                                fix on camera: https://, paidAt
#   stage3      feat/add-contract-test-gates     PR workflows: + contract-test (Microcks), both
#   stage3-red  feat/orders-currency             required currency the backends never send: red;
#                                                fix on camera: make it optional in both
#   stage4      feat/add-deploy-gates            PR workflows: + gateway (KrakenD), + broker policy
#   stage5      feat/add-breaking-changes-gates  PR workflows: + breaking changes, events publish on merge
#   stage5-red  feat/orders-channel-and-is-paid  required channel parameter, isPaid removed: red;
#                                                fix on camera: optional channel, deprecated isPaid
#   kafka       feat/kafka-paid-at               Kafka repo: catalog entry and optional paidAt, all gates green
#   kafka-red   feat/kafka-drop-is-paid          Kafka repo: isPaid removed, red (registry)
#
# Rollback: put Gitea main (both consumer repos), Backstage, the gateway,
# Microcks, the registry and the broker policy in the state right BEFORE a
# step (closes open PRs, deletes all feat/* branches), make fresh demo clones
# and prepare that step's branch. cd into the clone again if your terminal
# was inside the old one.
#   prep-stage.sh goto 1 | 2 | 2-red | 3 | 3-red | 4 | 5 | 5-red | kafka | end
#   prep-stage.sh reset            alias for: goto 1
#
#   prep-stage.sh refresh-catalog  make Backstage rescan Gitea now (a few seconds)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/scripts/demo/engine.sh"   # ENGINE (docker|podman), COMPOSE
U="${GITEA_ADMIN_USER:-demo}"
P="${GITEA_ADMIN_PASSWORD:-demo12345}"
GITEA="http://localhost:3000"
BACKSTAGE="http://localhost:7007"
MICROCKS="http://localhost:8080"
REGISTRY="http://localhost:8280/apis/registry/v3"
ORG="governance-demo"
REPO="devops-api-governance"       # the orders repo: REST + MQTT
KREPO="order-events-kafka-api"     # the Kafka repo
GOV_REPO="api-governance"
API="$GITEA/api/v1"
REMOTE="http://$U:$P@localhost:3000/$ORG/$REPO.git"
KREMOTE="http://$U:$P@localhost:3000/$ORG/$KREPO.git"
WF="$ROOT/scripts/demo/workflows"  # the REST workflow as it reads at stages 2-4
EV_WF_FULL="$ROOT/example/.gitea/workflows/pr-governance-events.yml"
RD="$ROOT/scripts/demo/readmes"    # the repo README as it reads at each stage
CONTRACT="contracts/orders-openapi.yaml"
EV_CONTRACT="contracts/order-events-asyncapi.yaml"
KCONTRACT="contracts/order-events-kafka-asyncapi.yaml"
DEMO_CLONE="${DEMO_CLONE:-$HOME/demo/orders-api}"   # the clone you record in
DEMO_KAFKA_CLONE="${DEMO_KAFKA_CLONE:-$HOME/demo/order-events-kafka-api}"
CI_IMAGE="localhost/devops-api-governance-ci:latest"
NETWORK="gitea-network"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

# Runs a governance script in the CI image on the compose network (the
# deployer, the registry and the brokers are reachable there). $1 = dir
# mounted at /w, the rest = command.
ci_run() {
  local dir="$1"; shift
  "$ENGINE" run --rm --network "$NETWORK" -v "$dir":/w:ro -v "$ROOT/governance":/governance:ro -w /w \
    -e REGISTRY_URL=http://apicurio:8080/apis/registry/v3 -e KAFKA_BROKERS=kafka:9092 \
    -e NO_PROXY='*' -e no_proxy='*' "$CI_IMAGE" "$@"
}

kafka_running() { "$ENGINE" ps --format '{{.Names}}' | grep -cx kafka >/dev/null; }

# --- the changes each step makes; every one takes the repo dir as $1 ---------

use_readme() { cp "$2" "$1/README.md"; }  # $1 = repo dir, $2 = README file

# REST: the PR workflow as it reads at a stage. $1 = repo dir, $2 = workflow file
use_rest_workflow() {
  mkdir -p "$1/.gitea/workflows"
  cp "$2" "$1/.gitea/workflows/pr-governance.yml"
}

# Events: the PR workflow with only some of the gates, in order: each gate
# needs the one before it. $1 = repo dir, $2.. = job names from the full workflow.
use_event_gates() {
  local d="$1"; shift
  mkdir -p "$d/.gitea/workflows"
  python3 - "$EV_WF_FULL" "$d/.gitea/workflows/pr-governance-events.yml" "$@" <<'PY'
import re, sys
src, out, keep = sys.argv[1], sys.argv[2], sys.argv[3:]
text = open(src).read()
head, jobs_text = text.split('\njobs:\n', 1)
# Header: keep the numbered gate descriptions of the kept gates, renumbered.
lines = head.split('\n')
i, out_lines, n = 0, [], 0
while i < len(lines):
    m = re.match(r'#   \d\. (\S+)', lines[i])
    if m:
        block = [lines[i]]; i += 1
        while i < len(lines) and re.match(r'#\s{6,}\S', lines[i]) and not re.match(r'#   \d\. ', lines[i]):
            block.append(lines[i]); i += 1
        if m.group(1) in keep:
            n += 1
            block[0] = re.sub(r'#   \d\.', f'#   {n}.', block[0])
            out_lines.extend(block)
        continue
    out_lines.append(lines[i]); i += 1
head = '\n'.join(out_lines)
# Jobs: split on the two-space job keys, keep the listed ones in order.
parts = re.split(r'(?m)^(?=  [a-z][a-z-]*:\n)', jobs_text)
jobs = {re.match(r'  ([a-z-]+):', p).group(1): p for p in parts if p.strip()}
body, prev = [], None
for name in keep:
    job = jobs[name]
    job = re.sub(r'(?m)^    needs: .*\n', '', job)
    if prev:
        job = job.replace(f'  {name}:\n', f'  {name}:\n    needs: {prev}\n', 1)
    body.append(job.rstrip('\n') + '\n')
    prev = name
open(out, 'w').write(head + '\njobs:\n' + '\n'.join(body))
PY
}

# Step 1: the catalog entry for both APIs.
do_stage1() {
  cp "$ROOT/example/catalog-info.yaml" "$1/"
  use_readme "$1" "$RD/stage1.md"
}

# Step 2: the lint gates.
do_stage2() {
  use_rest_workflow "$1" "$WF/stage2-openlint.yml"
  use_event_gates "$1" asyncapi-lint
  use_readme "$1" "$RD/stage2.md"
}
# REST: an http:// server URL. Events: an optional paid_at on OrderPaid,
# snake_case, which breaks the property naming rule.
do_stage2_red() {
  sed -i 's#url: https://api.api-peak.com#url: http://orders.api-peak.com#' "$1/$CONTRACT"
  python3 - "$1/$EV_CONTRACT" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = """        isPaid:
          type: boolean"""
assert s.count(old) == 1
s = s.replace(old, old + """
        paid_at:
          type: string
          format: date-time
          description: When the payment was confirmed.""")
open(p, 'w').write(s)
PY
}
do_stage2_fix() {
  sed -i 's#http://orders.api-peak.com#https://orders.api-peak.com#' "$1/$CONTRACT"
  sed -i 's/^        paid_at:$/        paidAt:/' "$1/$EV_CONTRACT"
}

# Step 3: the contract-test gates.
do_stage3() {
  use_rest_workflow "$1" "$WF/stage3-contract-test.yml"
  use_event_gates "$1" asyncapi-lint contract-test
  use_readme "$1" "$RD/stage3.md"
}
# Both contracts promise a currency the running backends don't send.
do_stage3_red() {
  python3 - "$1/$CONTRACT" <<'PY'
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
PY
  python3 - "$1/$EV_CONTRACT" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = """      required: [orderId, createdAt]
      properties:
        orderId:
          type: string
        createdAt:
          type: string
          format: date-time"""
assert s.count(old) == 1
s = s.replace(old, """      required: [orderId, createdAt, currency]
      properties:
        orderId:
          type: string
        createdAt:
          type: string
          format: date-time
        currency:
          type: string
          description: ISO 4217 code of the order total.""")
open(p, 'w').write(s)
PY
}
do_stage3_fix() {
  sed -i 's/required: \[orderId, isPaid, currency\]/required: [orderId, isPaid]/' "$1/$CONTRACT"
  sed -i 's/required: \[orderId, createdAt, currency\]/required: [orderId, createdAt]/' "$1/$EV_CONTRACT"
}

# Step 4: deploy from the contract: the gateway (REST), the broker policy (events).
do_stage4() {
  use_rest_workflow "$1" "$WF/stage4-gateway.yml"
  use_event_gates "$1" asyncapi-lint contract-test broker-policy
  use_readme "$1" "$RD/stage4.md"
}

# Step 5: the breaking-changes gates; the event schemas are published on merge.
do_stage5() {
  mkdir -p "$1/.gitea/workflows"
  cp "$ROOT/example/.gitea/workflows/pr-governance.yml" "$EV_WF_FULL" \
     "$ROOT/example/.gitea/workflows/main-publish.yml" "$1/.gitea/workflows/"
  use_readme "$1" "$ROOT/example/README.md"
}
# REST: a new required query parameter. Events: isPaid dropped from OrderPaid.
# Both break the clients that read them.
do_stage5_red() {
  python3 - "$1/$CONTRACT" <<'PY'
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
PY
  python3 - "$1/$EV_CONTRACT" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
for old, new in [("      required: [orderId, isPaid]\n", "      required: [orderId]\n"),
                 ("        isPaid:\n          type: boolean\n", ""),
                 ("            isPaid: true\n", "")]:
    assert s.count(old) == 1, old
    s = s.replace(old, new)
open(p, 'w').write(s)
PY
}
# The fixes: the parameter becomes optional; isPaid stays, marked deprecated.
do_stage5_fix() {
  sed -i '/name: channel/,/required:/ s/required: true/required: false/' "$1/$CONTRACT"
  python3 - "$1/$EV_CONTRACT" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
for old, new in [("      required: [orderId]\n", "      required: [orderId, isPaid]\n"),
                 ("          type: string\n        paidAt:\n",
                  "          type: string\n        isPaid:\n          type: boolean\n          deprecated: true\n        paidAt:\n"),
                 ("        - name: paidOrder\n          payload:\n            orderId: '123'\n",
                  "        - name: paidOrder\n          payload:\n            orderId: '123'\n            isPaid: true\n")]:
    assert s.count(old) == 1, old
    s = s.replace(old, new)
open(p, 'w').write(s)
PY
}

# Kafka repo: its catalog entry and an optional field (green), then a removed
# field (red). Until its step the Kafka API stays out of the catalog, so step 1
# shows the catalog filling with the REST and the MQTT API only.
do_kafka() {
  cp "$ROOT/example-kafka/catalog-info.yaml" "$1/"
  python3 - "$1/$KCONTRACT" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = """        isPaid:
          type: boolean"""
assert s.count(old) == 1
s = s.replace(old, old + """
        paidAt:
          type: string
          format: date-time
          description: When the payment was confirmed.""")
open(p, 'w').write(s)
PY
}
do_kafka_red() {
  python3 - "$1/$KCONTRACT" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
for old, new in [("      required: [orderId, isPaid]\n", "      required: [orderId]\n"),
                 ("        isPaid:\n          type: boolean\n", ""),
                 ("            isPaid: true\n", "")]:
    assert s.count(old) == 1, old
    s = s.replace(old, new)
open(p, 'w').write(s)
PY
}

# What lands on main, in order. "goto" replays the first N of these.
LAYERS=(
  "do_stage1"                       # 1  step 1: catalog entry
  "do_stage2"                       # 2  step 2 part 1: lint gates
  "do_stage2_red do_stage2_fix"     # 3  step 2 part 2: https and paidAt merged
  "do_stage3"                       # 4  step 3 part 1: contract-test gates
  "do_stage3_red do_stage3_fix"     # 5  step 3 part 2: optional currency merged
  "do_stage4"                       # 6  step 4: gateway and broker-policy gates
  "do_stage5"                       # 7  step 5 part 1: breaking-changes gates
  "do_stage5_red do_stage5_fix"     # 8  step 5 part 2: optional channel, deprecated isPaid merged
)
KLAYERS=("do_kafka")                # Kafka repo: 1 = optional paidAt merged

# goto target -> "<orders layers> <Kafka layers>"
layers_before() {
  case "$1" in
    1) echo "0 0" ;; 2) echo "1 0" ;; 2-red) echo "2 0" ;; 3) echo "3 0" ;; 3-red) echo "4 0" ;;
    4) echo "5 0" ;; 5) echo "6 0" ;; 5-red) echo "7 0" ;; kafka) echo "8 0" ;; end) echo "8 1" ;;
    *) return 1 ;;
  esac
}

# --- states --------------------------------------------------------------------

# $1 = dir, $2 = layers: the consumer template minus the catalog entry and the
# workflows (contracts and backends remain), plus the first $2 layers.
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

# The Kafka repo has the finished pipeline from the start, without its
# catalog entry (its step adds it).
build_kafka_state() {
  local d="$1" i f
  rm -rf "$d"; mkdir -p "$d"
  cp -a "$ROOT/example-kafka/." "$d/"
  rm -f "$d/catalog-info.yaml"
  for ((i = 0; i < $2; i++)); do
    for f in ${KLAYERS[$i]}; do "$f" "$d"; done
  done
}

push_dir() {  # $1 = dir, $2 = remote, $3 = message
  git -C "$1" init -q
  git -C "$1" -c user.name=seed -c user.email=seed@example.com add -A
  git -C "$1" -c user.name=seed -c user.email=seed@example.com commit -q -m "$3"
  git -C "$1" -c push.negotiate=false push -q -f "$2" HEAD:main
}

# The states with the first $1 (orders) and $2 (Kafka) layers, pushed as fresh
# root commits onto Gitea main. Leaves them in $WORK/base and $WORK/kbase.
push_state() {
  build_state "$WORK/base" "$1"
  push_dir "$WORK/base" "$REMOTE" "Consumer repo: Orders API and Order Events API"
  echo "pushed state with $1 of ${#LAYERS[@]} layers to $REPO main"
  build_kafka_state "$WORK/kbase" "$2"
  push_dir "$WORK/kbase" "$KREMOTE" "Consumer repo: Order Events Kafka API"
  echo "pushed state with $2 of ${#KLAYERS[@]} layers to $KREPO main"
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
detect_kafka_layers() {
  local cur="$WORK/kcur" k
  rm -rf "$cur"; git clone -q "$KREMOTE" "$cur"; rm -rf "$cur/.git"
  for ((k = 0; k <= ${#KLAYERS[@]}; k++)); do
    build_kafka_state "$WORK/kst" "$k"
    diff -rq "$cur" "$WORK/kst" >/dev/null 2>&1 && { echo "$k"; return 0; }
  done
  return 1
}

# --- rollback ------------------------------------------------------------------

# Same lean policy repo gitea-seed publishes, from this working tree
# (scripts/governance-bundle.sh).
sync_governance_repo() {
  local g="$WORK/gov"
  sh "$ROOT/scripts/governance-bundle.sh" "$ROOT/governance" "$g"
  push_dir "$g" "http://$U:$P@localhost:3000/$ORG/$GOV_REPO.git" "Governance policy: rulesets, gate scripts and guidelines"
  echo "synced $GOV_REPO"
}

# CI runs still going (from an abandoned take) keep going after their PR is
# closed: a late gateway or broker-policy job would redeploy the gateway or
# the policy, a late contract test would reload a Microcks mock, after goto
# has reset them.
ci_active_runs() {
  local r n=0
  for r in "$REPO" "$KREPO"; do
    n=$((n + $(curl -sf -u "$U:$P" "$API/repos/$ORG/$r/actions/runs?limit=20" \
      | json "sum(r['status'] != 'completed' for r in d['workflow_runs'])")))
  done
  echo "$n"
}
wait_for_idle_ci() {
  local n i
  for ((i = 1; i <= 120; i++)); do
    n="$(ci_active_runs)"
    [ "$n" = 0 ] && return 0
    [ "$i" = 1 ] && echo "waiting for $n CI run(s) from an earlier take to finish (up to 4 min)..."
    sleep 2
  done
  echo "CI is still busy after 4 min; check $GITEA/$ORG/$REPO/actions" >&2; exit 1
}

# Close open PRs and delete leftover feat/* branches from earlier runs.
cleanup_gitea() {
  local r n b
  for r in "$REPO" "$KREPO"; do
    for n in $(curl -sf -u "$U:$P" "$API/repos/$ORG/$r/pulls?state=open&limit=50" | json "' '.join(str(p['number']) for p in d)"); do
      curl -sf -o /dev/null -u "$U:$P" -X PATCH -H 'Content-Type: application/json' \
        -d '{"state":"closed"}' "$API/repos/$ORG/$r/pulls/$n"
      echo "closed $r PR #$n"
    done
    for b in $(curl -sf -u "$U:$P" "$API/repos/$ORG/$r/branches?limit=100" \
        | json "' '.join(b['name'] for b in d if b['name'].startswith('feat/'))"); do
      curl -sf -o /dev/null -u "$U:$P" -X DELETE "$API/repos/$ORG/$r/branches/$b"
      echo "deleted $r branch $b"
    done
  done
}

# The broker policy follows the full catalog in every state (the backends and
# the subscribers run from the start); goto re-applies it in case a take
# applied a PR's policy.
sync_broker_policy() {
  ci_run "$ROOT" sh -c '
    for c in example/contracts/order-events-asyncapi.yaml:example/catalog-info.yaml \
             example-kafka/contracts/order-events-kafka-asyncapi.yaml:example-kafka/catalog-info.yaml; do
      node /governance/broker-policy/generate-policy.js "${c%%:*}" "${c##*:}" /tmp/p.json &&
      curl -sf --noproxy "*" -X POST -H "Content-Type: application/json" --data-binary @/tmp/p.json \
        http://broker-policy-deployer:9100/deploy >/dev/null || exit 1
    done' \
    && echo "broker policy applied (MQTT and Kafka)" \
    || echo "warning: could not apply the Kafka broker policy (is the kafka profile up?)" >&2
}

# The registry holds what is on main: drop the API's group, register the
# state's contract. $1 = state dir, $2 = contract path in it.
sync_registry() {
  local group
  # The group is the API title as a slug (schema-registry.js does the same).
  group="$(sed -n 's/^  title: *//p' "$1/$2" | head -1 | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
  curl -s -o /dev/null -X DELETE "$REGISTRY/groups/$group"
  ci_run "$1" node /governance/breaking-changes/schema-registry.js register "$2" >/dev/null \
    && echo "registry: $group holds the state's schemas" \
    || { echo "could not register $2 in the registry" >&2; exit 1; }
}

# Microcks serves the last contract imported under a title as the mock, so
# load the state's contracts: the mocks then match what is merged.
sync_microcks() {  # $1 = contract file
  curl -sf -o /dev/null -X POST -F "file=@$1" "$MICROCKS/api/artifact/upload?mainArtifact=true" \
    || { echo "could not load $1 into Microcks" >&2; exit 1; }
  echo "microcks mock matches $(basename "$1")"
}

# KrakenD keeps the config CI last deployed, so it must be put back in step
# with the stage: until the gateway gate is merged the gateway has no routes
# (404); afterwards it serves the contract. Posts to the deployer sidecar,
# which writes the config and restarts krakend.
gateway_deploy() {  # $1 = krakend.json
  "$ENGINE" exec krakend-deployer wget -qO- --header 'Content-Type: application/json' \
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

backstage_token() {
  curl -sf -X POST "$BACKSTAGE/api/auth/guest/refresh" | json "d['backstageIdentity']['token']"
}

# Drop the catalog entities the consumer repos registered (APIs, Components, ...).
delete_repo_entities() {
  local t uid; t="$(backstage_token)"
  for uid in $(curl -sf -H "Authorization: Bearer $t" "$BACKSTAGE/api/catalog/entities" \
      | json "' '.join(e['metadata']['uid'] for e in d if any('/'+r+'/' in e['metadata'].get('annotations',{}).get('backstage.io/managed-by-location','') for r in ('$REPO','$KREPO')))"); do
    curl -sf -o /dev/null -X DELETE -H "Authorization: Bearer $t" "$BACKSTAGE/api/catalog/entities/by-uid/$uid"
    echo "deleted catalog entity $uid"
  done
}

# TechDocs builds a page the first time it is opened (a "building" banner on
# camera). The governance repo was just re-pushed, so build it now.
prewarm_techdocs() {
  local t; t="$(backstage_token)"
  curl -s -N --max-time 240 -H "Authorization: Bearer $t" -H "Accept: text/event-stream" \
    "$BACKSTAGE/api/techdocs/sync/default/component/api-guidelines" | grep >/dev/null -c "^event: finish" \
    && echo "api guidelines (TechDocs) built" \
    || echo "warning: TechDocs build did not finish; open the guidelines once before recording" >&2
}

# Never run compose `up` mid-demo, and on Podman never start/restart backstage
# either: that runs its dependency gitea-seed, which force-pushes the full
# repos over Gitea main and wipes the stage state. Instead, trigger the Gitea
# provider's scheduled task: it rescans Gitea in a few seconds.
trigger_refresh() {
  local t; t="$(backstage_token)"
  curl -sf -o /dev/null -X POST -H "Authorization: Bearer $t" \
    "$BACKSTAGE/api/catalog/.backstage/scheduler/v1/tasks/gitea-provider:local:refresh/trigger" \
    || echo "warning: could not trigger the Backstage refresh" >&2
}

# 0 when Backstage lists both APIs of the orders repo.
catalog_has_api() {
  local t; t="$(backstage_token)" || return 1
  curl -sf -H "Authorization: Bearer $t" "$BACKSTAGE/api/catalog/entities?filter=kind=api" \
    | python3 -c "import json,sys; n={e['metadata']['name'] for e in json.load(sys.stdin)}; sys.exit(0 if {'orders-api','order-events-api'} <= n else 1)"
}
# 0 when Backstage lists the Kafka API.
catalog_has_kafka_api() {
  local t; t="$(backstage_token)" || return 1
  curl -sf -H "Authorization: Bearer $t" "$BACKSTAGE/api/catalog/entities?filter=kind=api" \
    | python3 -c "import json,sys; sys.exit(0 if any(e['metadata']['name']=='$KREPO' for e in json.load(sys.stdin)) else 1)"
}
# 0 when Backstage lists neither of them.
catalog_has_no_api() {
  local t; t="$(backstage_token)" || return 1
  curl -sf -H "Authorization: Bearer $t" "$BACKSTAGE/api/catalog/entities?filter=kind=api" \
    | python3 -c "import json,sys; n={e['metadata']['name'] for e in json.load(sys.stdin)}; sys.exit(1 if n & {'orders-api','order-events-api'} else 0)"
}

wait_for_api() {  # $1 = attempts, 3s apart
  local n
  for ((n = 1; n <= $1; n++)); do
    catalog_has_api && return 0
    sleep 3
  done
  return 1
}

refresh_catalog() {
  trigger_refresh
  if wait_for_api 15; then echo "backstage lists orders-api and order-events-api"
  else echo "the APIs are not listed yet (is catalog-info.yaml on Gitea main?)"; fi
}

# --- demo clones and branches --------------------------------------------------

# Refuse to delete anything that is not a previous clone of the demo repo.
check_clone() {  # $1 = clone dir, $2 = repo name
  [ -e "$1" ] || return 0
  case "$(git -C "$1" remote get-url origin 2>/dev/null)" in
    *"/$ORG/$2.git") ;;
    *) echo "refusing to replace $1: it is not a clone of $ORG/$2 (move it away or set DEMO_CLONE / DEMO_KAFKA_CLONE)" >&2; exit 1 ;;
  esac
}

fresh_clone() {  # $1 = clone dir, $2 = repo name, $3 = remote
  check_clone "$1" "$2"
  rm -rf "$1"
  mkdir -p "$(dirname "$1")"
  git clone -q "$3" "$1"
  echo "demo clone ready: $1"
}

# Branch that exists only in the demo clone, committed on top of the current
# Gitea main but NOT pushed: the presenter pushes it on camera. Done in a
# temporary worktree, so whatever the recording terminal has checked out stays
# untouched. $1 = clone, $2 = repo, $3 = remote, $4 = branch, $5 = message,
# $6.. = change functions.
make_local_branch() {
  local clone="$1" repo="$2" remote="$3" branch="$4" msg="$5"; shift 5
  local g=(git -C "$clone") cur wt="$WORK/wt"
  [ -d "$clone/.git" ] || fresh_clone "$clone" "$repo" "$remote"
  check_clone "$clone" "$repo"
  if git ls-remote --exit-code "$remote" "refs/heads/$branch" >/dev/null; then
    echo "Gitea already has branch $branch (from an earlier take). Run 'goto <target>' to reset, or delete that branch first." >&2
    exit 1
  fi
  "${g[@]}" fetch -q --prune origin
  # Bring the local main up to the Gitea main, without switching branches.
  cur="$("${g[@]}" branch --show-current)"
  if [ "$cur" = main ]; then
    "${g[@]}" merge -q --ff-only origin/main \
      || { echo "cannot fast-forward main in $clone (local changes or commits on main?)" >&2; exit 1; }
  else
    "${g[@]}" branch -f main origin/main
  fi
  if "${g[@]}" show-ref --verify -q "refs/heads/$branch"; then
    [ "$cur" = "$branch" ] && { echo "$branch is checked out in $clone; switch to main first" >&2; exit 1; }
    "${g[@]}" branch -q -D "$branch"
  fi
  "${g[@]}" worktree add -q -b "$branch" "$wt" origin/main
  for f in "$@"; do "$f" "$wt"; done
  git -C "$wt" add -A
  git -C "$wt" -c user.name="$U" -c user.email="$U@example.com" commit -q -m "$msg"
  "${g[@]}" worktree remove --force "$wt"
  echo "local branch $branch ready in $clone (not pushed; main updated to Gitea main)"
}

orders_branch() { make_local_branch "$DEMO_CLONE" "$REPO" "$REMOTE" "$@"; }
kafka_branch() { make_local_branch "$DEMO_KAFKA_CLONE" "$KREPO" "$KREMOTE" "$@"; }

# What each prep step prepares: the branch you check out on camera.
prep_step() {
  case "$1" in
    stage1)     orders_branch "$(branch_of "$1")" "Register the Orders API and the Order Events API in the catalog" do_stage1 ;;
    stage2)     orders_branch "$(branch_of "$1")" "Add the lint gates (OpenLint, AsyncAPI)" do_stage2 ;;
    stage2-red) orders_branch "$(branch_of "$1")" "Move the Orders API to orders.api-peak.com, add when an order was paid" do_stage2_red ;;
    stage3)     orders_branch "$(branch_of "$1")" "Add the contract-test gates (Microcks)" do_stage3 ;;
    stage3-red) orders_branch "$(branch_of "$1")" "Add the currency to the order and to OrderCreated" do_stage3_red ;;
    stage4)     orders_branch "$(branch_of "$1")" "Add the deploy gates (KrakenD gateway, broker policy)" do_stage4 ;;
    stage5)     orders_branch "$(branch_of "$1")" "Insert the breaking-changes gates between lint and contract-test" do_stage5 ;;
    stage5-red) orders_branch "$(branch_of "$1")" "Require the sales channel, drop isPaid from OrderPaid" do_stage5_red ;;
    kafka)      kafka_branch "$(branch_of "$1")" "Register the Kafka API in the catalog, add when an order was paid" do_kafka ;;
    kafka-red)  kafka_branch "$(branch_of "$1")" "Drop isPaid from OrderPaid" do_kafka_red ;;
    *) return 1 ;;
  esac
}

branch_of() {
  case "$1" in
    stage1) echo feat/add-catalog-entry ;;          stage2) echo feat/add-lint-gates ;;
    stage2-red) echo feat/orders-server-and-paid-at ;; stage3) echo feat/add-contract-test-gates ;;
    stage3-red) echo feat/orders-currency ;;        stage4) echo feat/add-deploy-gates ;;
    stage5) echo feat/add-breaking-changes-gates ;; stage5-red) echo feat/orders-channel-and-is-paid ;;
    kafka) echo feat/kafka-paid-at ;;               kafka-red) echo feat/kafka-drop-is-paid ;;
  esac
}
remote_of() { case "$1" in kafka*) echo "$KREMOTE" ;; *) echo "$REMOTE" ;; esac; }
clone_of() { case "$1" in kafka*) echo "$DEMO_KAFKA_CLONE" ;; *) echo "$DEMO_CLONE" ;; esac; }

# The step recorded after $1 orders layers and $2 Kafka layers are merged.
step_after() {
  local steps=(stage1 stage2 stage2-red stage3 stage3-red stage4 stage5 stage5-red)
  if [ "$1" -lt "${#LAYERS[@]}" ]; then echo "${steps[$1]}"
  elif [ "$2" = 0 ]; then echo kafka
  else echo kafka-red; fi
}

# The step that is recorded from each goto state.
step_at() {
  case "$1" in
    1) echo stage1 ;; 2) echo stage2 ;; 2-red) echo stage2-red ;; 3) echo stage3 ;;
    3-red) echo stage3-red ;; 4) echo stage4 ;; 5) echo stage5 ;; 5-red) echo stage5-red ;;
    kafka) echo kafka ;; end) echo kafka-red ;;
  esac
}

# Work out where the demo is and prepare the next branch (or just report it).
next_step() {  # $1 = "prepare" or "status"
  local k kk step branch remote clone
  k="$(detect_layers)" || { echo "Gitea main of $REPO matches no demo state (after compose up, or a half-done step?). Use: demo goto <target>" >&2; exit 1; }
  kk="$(detect_kafka_layers)" || { echo "Gitea main of $KREPO matches no demo state. Use: demo goto <target>" >&2; exit 1; }
  step="$(step_after "$k" "$kk")"
  echo "Gitea main: $k of ${#LAYERS[@]} steps and $kk of ${#KLAYERS[@]} Kafka steps merged."
  branch="$(branch_of "$step")"; remote="$(remote_of "$step")"; clone="$(clone_of "$step")"
  echo "Next: $step, branch $branch."
  if git ls-remote --exit-code "$remote" "refs/heads/$branch" >/dev/null; then
    if [ "$step" = kafka-red ]; then echo "$branch is on Gitea: that was the last step (its PR stays red, not merged)."
    else echo "$branch is already on Gitea: open (or finish) its PR and merge it; then run next again."; fi
  elif [ -d "$clone/.git" ] && git -C "$clone" show-ref --verify -q "refs/heads/$branch"; then
    echo "$branch is already prepared in $clone: git switch $branch"
  elif [ "$1" = prepare ]; then
    prep_step "$step"
  fi
}

# --- the broker saying no --------------------------------------------------------

deny() {
  local sub=(-u orders-subscriber -P orders-subscriber-pw)
  run() { echo "\$ $*"; "$@" 2>&1 | sed 's/^/  /'; echo; }
  echo "A consumer asks for a topic the contract does not have:"
  run "$ENGINE" exec mosquitto mosquitto_sub "${sub[@]}" -t 'orders/v1/+/refunded' -C 1 -W 5 || true
  echo "... or for more than the contract gives it:"
  run "$ENGINE" exec mosquitto mosquitto_sub "${sub[@]}" -t 'orders/v1/#' -C 1 -W 5 || true
  echo "... or connects without an account:"
  run "$ENGINE" exec mosquitto mosquitto_sub -t 'orders/v1/+/paid' -C 1 -W 5 || true
  if kafka_running; then
    echo "On Kafka, a topic the contract does not have:"
    echo "\$ kafka-console-consumer.sh --bootstrap-server kafka:9094 --topic orders.not-in-contract.v1"
    "$ENGINE" exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9094 \
      --topic orders.not-in-contract.v1 --max-messages 1 --timeout-ms 8000 2>&1 \
      | grep -o 'Topic authorization failed for topics \[[^]]*\]' | head -1 | sed 's/^/  /' || true
  fi
}

# --- preflight -----------------------------------------------------------------

# Read-only "ready to record?" check against whatever state Gitea main is in.
preflight() {
  local problems=0 k kk step branch remote clone t names ours foreign want c
  pass() { echo "  ok       $*"; }
  miss() { echo "  PROBLEM  $*"; problems=$((problems + 1)); }
  code() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

  echo "Stack"
  names="$("$ENGINE" ps --format '{{.Names}}')"
  for c in gitea gitea-runner backstage backend krakend krakend-deployer \
           microcks-uber microcks-async-minion mosquitto mqtt-backend mqtt-subscriber \
           broker-policy-deployer apicurio kafka kafka-backend kafka-subscriber; do
    grep -qx "$c" <<<"$names" && pass "container $c running" \
      || miss "container $c not running (${COMPOSE[*]} --profile contract --profile catalog --profile gateway --profile events --profile kafka up -d, then demo goto 1)"
  done
  # A label filter instead of a Labels template: Docker formats Labels as a
  # string and Podman as a map, but both filter the same way.
  ours="$("$ENGINE" ps --filter label=com.docker.compose.project=devops-api-governance --format '{{.Names}}')"
  foreign="$( (grep -vxF -f <(echo "$ours") <<<"$names" || true) | tr "\n" " ")"
  [ -z "$foreign" ] && pass "no containers from other projects" || miss "other containers running: $foreign(ports may clash)"
  for u in "$GITEA/api/healthz" "$MICROCKS/api/health" http://localhost:8081/health "$REGISTRY/system/info" "$BACKSTAGE"; do
    [ "$(code "$u")" = 200 ] && pass "$u answers" || miss "$u does not answer"
  done
  "$ENGINE" logs gitea-runner 2>&1 | grep >/dev/null -c "declare successfully" && pass "CI runner registered" || miss "CI runner not registered"
  "$ENGINE" image inspect "$CI_IMAGE" >/dev/null 2>&1 && pass "CI image present (CI runs offline)" || miss "CI image missing (${COMPOSE[*]} up builds it)"

  echo "Demo state"
  if ! k="$(detect_layers)" || ! kk="$(detect_kafka_layers)"; then
    miss "Gitea main matches no demo state: run goto 1 (or goto <target>)"
    echo; echo "NOT READY: $problems problem(s)"; return 1
  fi
  step="$(step_after "$k" "$kk")"; branch="$(branch_of "$step")"; remote="$(remote_of "$step")"; clone="$(clone_of "$step")"
  pass "Gitea main: $k of ${#LAYERS[@]} steps and $kk of ${#KLAYERS[@]} Kafka steps merged; next: $step"
  [ "$(ci_active_runs)" = 0 ] && pass "no CI running" || miss "CI is still running (an earlier take?): wait for it, then goto <target>"
  local open=0 r
  for r in "$REPO" "$KREPO"; do
    open=$((open + $(curl -sf -u "$U:$P" "$API/repos/$ORG/$r/pulls?state=open" | json 'len(d)')))
  done
  [ "$open" = 0 ] && pass "no open PRs" || miss "open PRs on Gitea: merge or close them (goto closes them)"
  git ls-remote --exit-code "$remote" "refs/heads/$branch" >/dev/null \
    && miss "$branch is already on Gitea (half-done step?): finish its PR, or goto"
  if [ "$k" -ge 1 ]; then
    catalog_has_api && pass "Backstage lists orders-api and order-events-api" || miss "Backstage does not list both APIs yet: refresh-catalog"
  else
    catalog_has_no_api && pass "Backstage lists neither API yet (Stage 1 before)" || miss "Backstage lists an API before Stage 1 is merged: goto 1"
  fi
  if catalog_has_kafka_api; then
    [ "$kk" -ge 1 ] && pass "Backstage lists $KREPO" || miss "Backstage lists $KREPO before the Kafka step is merged: goto <target>"
  else
    [ "$kk" -ge 1 ] && miss "Backstage does not list $KREPO yet: refresh-catalog" || pass "Backstage does not list $KREPO yet (Kafka step before)"
  fi
  if [ "$k" -ge 6 ]; then want=200; else want=404; fi
  [ "$(code http://localhost:8090/orders/123)" = "$want" ] && pass "gateway answers $want (as it should at this point)" || miss "gateway does not answer $want: goto <target> resets it"
  build_state "$WORK/pf" "$k"
  if python3 - "$WORK/pf/$CONTRACT" "$(curl -s "$MICROCKS/rest/Orders+API/1.0.0/orders/123")" <<'PY'
import json, sys, yaml
c = yaml.safe_load(open(sys.argv[1]))
ex = c['paths']['/orders/{orderId}']['get']['responses']['200']['content']['application/json']['examples']['order_123']['value']
sys.exit(0 if json.loads(sys.argv[2] or 'null') == ex else 1)
PY
  then pass "Microcks REST mock matches the merged contract"; else miss "Microcks REST mock differs from the merged contract: goto <target> reloads it"; fi
  curl -sf "$MICROCKS/api/services?size=50" | python3 -c "import json,sys; sys.exit(0 if any(s['name']=='Order Events API' for s in json.load(sys.stdin)) else 1)" \
    && pass "Microcks has the Order Events API" || miss "Microcks lacks the Order Events API: goto loads it"
  ci_run "$WORK/pf" node /governance/breaking-changes/schema-registry.js check "$EV_CONTRACT" >/dev/null 2>&1 \
    && pass "registry accepts the merged event contract" || miss "registry rejects the merged event contract: goto resets it"
  ci_run "$ROOT/example" sh -c 'BROKER_CREDENTIALS=orders-subscriber:orders-subscriber-pw,orders-backend:orders-backend-pw node /governance/broker-policy/verify-policy.js contracts/order-events-asyncapi.yaml catalog-info.yaml' >/dev/null 2>&1 \
    && pass "MQTT broker policy matches the contract and the catalog" || miss "MQTT broker policy differs: goto re-applies it"
  "$ENGINE" logs --since 30s mqtt-subscriber 2>&1 | grep -c 'orders/v1/' >/dev/null \
    && pass "the MQTT subscriber receives events" || miss "the MQTT subscriber received nothing in the last 30 s (docker compose logs mqtt-subscriber)"
  t="$(backstage_token)"
  curl -sf -H "Authorization: Bearer $t" "$BACKSTAGE/api/techdocs/static/docs/default/component/api-guidelines/index.html" \
    | grep >/dev/null -c 'id="topic-naming-api-peakmqtt12026-topic-naming"' && pass "API guidelines page built in Backstage" \
    || miss "API guidelines page not built: goto builds it"

  echo "Demo clones"
  local rr clone_dir
  for c in "$DEMO_CLONE:$REMOTE" "$DEMO_KAFKA_CLONE:$KREMOTE"; do
    clone_dir="${c%%:http*}"; rr="${c#"$clone_dir":}"
    if [ ! -d "$clone_dir/.git" ]; then miss "no clone at $clone_dir: goto <target> creates it"; continue; fi
    local g=(git -C "$clone_dir") cur
    [ -z "$("${g[@]}" status --porcelain)" ] && pass "$clone_dir: no uncommitted changes" || miss "$clone_dir: uncommitted changes"
    cur="$("${g[@]}" branch --show-current)"
    [ "$cur" = main ] && pass "$clone_dir: on main" || echo "  note     $clone_dir: on $cur (fine if you are mid-stage)"
    [ "$("${g[@]}" rev-parse main)" = "$(git ls-remote "$rr" refs/heads/main | cut -f1)" ] \
      && pass "$clone_dir: local main = Gitea main" || miss "$clone_dir: local main differs from Gitea main: run next (updates it) or goto"
  done
  git -C "$clone" show-ref --verify -q "refs/heads/$branch" 2>/dev/null \
    && pass "next branch $branch prepared in $clone" || miss "next branch $branch not prepared: run next"

  echo
  if [ "$problems" = 0 ]; then
    echo "READY: record $step (cd $clone; git switch $branch)."
    echo "Not checked here: that the browser is signed in to Gitea as demo."
  else
    echo "NOT READY: $problems problem(s) above."; return 1
  fi
}

# --- goto ----------------------------------------------------------------------

goto() {
  local target="${1:-}" layers k kk step
  layers="$(layers_before "$target")" || { echo "unknown target '$target'; see the usage at the top of $0" >&2; exit 1; }
  read -r k kk <<<"$layers"
  check_clone "$DEMO_CLONE" "$REPO"; check_clone "$DEMO_KAFKA_CLONE" "$KREPO"   # fail before changing anything
  wait_for_idle_ci
  cleanup_gitea
  push_state "$k" "$kk"
  sync_governance_repo
  delete_repo_entities
  sync_gateway "$k"
  sync_broker_policy
  sync_registry "$WORK/base" "$EV_CONTRACT"
  if kafka_running; then sync_registry "$WORK/kbase" "$KCONTRACT"; fi
  sync_microcks "$WORK/base/$CONTRACT"
  sync_microcks "$WORK/base/$EV_CONTRACT"
  sync_microcks "$WORK/kbase/$KCONTRACT"
  prewarm_techdocs
  trigger_refresh
  if [ "$k" -ge 1 ]; then
    # Stage 1 is already merged in this state, so Backstage must list both APIs.
    wait_for_api 40 || { echo "the APIs never appeared in Backstage" >&2; exit 1; }
    echo "backstage lists orders-api and order-events-api"
  fi
  # A pushed main with the publish workflow starts a run: let it finish.
  wait_for_idle_ci
  fresh_clone "$DEMO_CLONE" "$REPO" "$REMOTE"
  fresh_clone "$DEMO_KAFKA_CLONE" "$KREPO" "$KREMOTE"
  step="$(step_at "$target")"
  prep_step "$step"
  echo "ready: start of '$target'. Work in $(clone_of "$step") (cd there again if your terminal was inside the old clone)."
}

case "${1:-}" in
  goto) goto "${2:-}" ;;
  reset) goto 1 ;;
  next) next_step prepare ;;
  status) next_step status ;;
  preflight) preflight ;;
  deny) deny ;;
  refresh-catalog) refresh_catalog ;;
  stage1|stage2|stage2-red|stage3|stage3-red|stage4|stage5|stage5-red|kafka|kafka-red) prep_step "$1" ;;
  *) sed -n '2,49p' "$0"; exit 1 ;;
esac
