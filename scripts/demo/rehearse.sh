#!/bin/bash
# Full dry run of presentation/screenplay.md against the live stack: every
# terminal command the presenter types (in a throwaway clone, never the real
# ~/demo/orders-api), real PRs and CI, every red/fix loop, then every
# `goto <target>` compared with the state the real walk-through produced.
# Takes ~15 min. It resets the demo state; run `prep-stage.sh goto 1` afterwards.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREP="$ROOT/scripts/demo/prep-stage.sh"
. "$ROOT/scripts/demo/engine.sh"   # ENGINE (docker|podman)
BASE=http://localhost:3000/governance-demo/devops-api-governance
A=http://localhost:3000/api/v1/repos/governance-demo/devops-api-governance
C=(-u demo:demo12345)
REMOTE=http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
CL="$W/clone"                        # the presenter's clone for the walk-through
export GIT_AUTHOR_NAME=demo GIT_AUTHOR_EMAIL=demo@example.com GIT_COMMITTER_NAME=demo GIT_COMMITTER_EMAIL=demo@example.com
PASS=0; FAIL=0
ok()  { echo "  PASS: $*"; PASS=$((PASS+1)); }
bad() { echo "  FAIL: $*"; FAIL=$((FAIL+1)); }
sec() { echo; echo "### $* ($(date +%H:%M:%S))"; }
prep() { DEMO_CLONE="$CL" "$PREP" "$@" 2>&1 | grep -E "ready|rror|refus|never|should|already|cannot"; }

open_pr() { curl -s "${C[@]}" -X POST -H 'Content-Type: application/json' -d "{\"title\":\"$2\",\"head\":\"$1\",\"base\":\"main\"}" $A/pulls | python3 -c "import json,sys; print(json.load(sys.stdin)['number'])"; }
head_sha() { curl -s "${C[@]}" $A/pulls/$1 | python3 -c "import json,sys; print(json.load(sys.stdin)['head']['sha'])"; }
merge_pr() { local c; c=$(curl -s -o /dev/null -w '%{http_code}' "${C[@]}" -X POST -H 'Content-Type: application/json' -d '{"Do":"merge"}' $A/pulls/$1/merge); [ "$c" = 200 ] && ok "merged PR #$1" || bad "merge PR #$1 -> $c"; }
on_remote() { git ls-remote --exit-code "$REMOTE" "refs/heads/$1" >/dev/null; }

# $1 = PR, $2 = previous head sha (optional). Waits until no status is pending.
ci() {
  local sha i
  if [ -n "${2:-}" ]; then for i in $(seq 1 20); do [ "$(head_sha $1)" != "$2" ] && break; sleep 2; done; fi
  sha=$(head_sha $1); sleep 5
  for i in $(seq 1 120); do
    STATUSES=$(curl -s "${C[@]}" $A/commits/$sha/statuses | python3 -c "
import json,sys
seen={}
for s in json.load(sys.stdin): seen.setdefault(s['context'].split(' / ')[-1].replace(' (pull_request)',''), (s['status'], s.get('description')))
for k in sorted(seen): print(seen[k][0], k, '|', seen[k][1])")
    [ -n "$STATUSES" ] && ! echo "$STATUSES" | grep >/dev/null -c '^pending' && break
    sleep 5
  done
  if echo "$STATUSES" | grep >/dev/null -c '^failure'; then CI_STATE=failure; else CI_STATE=success; fi
  echo "  CI PR#$1: $CI_STATE"; echo "$STATUSES" | sed 's/^/     /'
}
has() { echo "$STATUSES" | grep >/dev/null -c "^$1 $2 "; }
n_success() { echo "$STATUSES" | grep -c '^success'; }
job_log() {
  local r j
  r=$(curl -s "${C[@]}" "$A/actions/runs?limit=1" | python3 -c "import json,sys; print(json.load(sys.stdin)['workflow_runs'][0]['id'])")
  j=$(curl -s "${C[@]}" "$A/actions/runs/$r/jobs" | python3 -c "import json,sys; n=sys.argv[1]; print([x['id'] for x in json.load(sys.stdin)['jobs'] if x['name']==n][0])" "$1")
  curl -s "${C[@]}" "$A/actions/jobs/$j/logs"
}
snap() { rm -rf "$W/snap-$1"; git clone -q "$REMOTE" "$W/snap-$1" && rm -rf "$W/snap-$1/.git"; }
main_files() { curl -s "${C[@]}" "$A/contents?ref=main" | python3 -c "import json,sys; print(','.join(sorted(x['name'] for x in json.load(sys.stdin))))"; }
api_listed() {
  local t; t=$(curl -s -X POST http://localhost:7007/api/auth/guest/refresh | python3 -c "import json,sys; print(json.load(sys.stdin)['backstageIdentity']['token'])")
  curl -s -H "Authorization: Bearer $t" "http://localhost:7007/api/catalog/entities?filter=kind=api" | python3 -c "import json,sys; print(','.join(e['metadata']['name'] for e in json.load(sys.stdin)))"
}
gw() { curl -s -o /dev/null -w '%{http_code}' http://localhost:8090/orders/123; }
MOCK=http://localhost:8080/rest/Orders+API/1.0.0/orders/123
GUIDE=http://localhost:7007/docs/default/component/api-guidelines
has_currency() { curl -s "$1" | python3 -c "import json,sys; sys.exit(0 if 'currency' in json.load(sys.stdin) else 1)"; }
techdocs_has_anchor() {
  local t; t=$(curl -s -X POST http://localhost:7007/api/auth/guest/refresh | python3 -c "import json,sys; print(json.load(sys.stdin)['backstageIdentity']['token'])")
  curl -s -H "Authorization: Bearer $t" http://localhost:7007/api/techdocs/static/docs/default/component/api-guidelines/index.html | grep >/dev/null -c "id=\"$1\""
}
seed_started() { "$ENGINE" inspect gitea-seed --format '{{.State.StartedAt}}'; }

# Presenter, on camera: switch to the prepared branch, check it is local only.
take_branch() {  # $1 = branch
  on_remote "$1" && bad "$1 already on Gitea before the presenter pushed it" || ok "$1 not on Gitea before the push"
  git -C "$CL" switch -q "$1" && ok "git switch $1 (local branch)" || bad "git switch $1"
}
# Gitea registers a pushed branch asynchronously; a PR opened in the same second
# gets closed as "head branch deleted". A presenter clicking in the browser is
# never that fast, so wait until the API lists the branch.
push_branch() {
  git -C "$CL" push -q -u origin "$1" 2>&1 | grep -v '^remote'
  local i; for i in $(seq 1 20); do
    curl -sf -o /dev/null "${C[@]}" "$A/branches/$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1")" && break; sleep 1
  done
  sleep 2
  on_remote "$1" && ok "git push -u origin $1" || bad "push $1"
}
# The next prep runs while the presenter is still on the merged branch.
prep_keeps_checkout() {  # $1 = the step `next` must pick
  local before out; before=$(git -C "$CL" branch --show-current)
  out=$(DEMO_CLONE="$CL" "$PREP" next 2>&1); echo "$out" | grep -E "Next:|rror|refus|cannot|already"
  echo "$out" | grep >/dev/null -c "^Next: $1," && ok "next picked $1" || bad "next did not pick $1"
  [ "$(git -C "$CL" branch --show-current)" = "$before" ] && ok "next left the checkout on $before" || bad "next switched the checkout"
  [ "$(git -C "$CL" rev-parse main)" = "$(git ls-remote "$REMOTE" refs/heads/main | cut -f1)" ] && ok "next updated local main to Gitea main" || bad "local main not updated"
}

SEED0=$(seed_started); T0=$SECONDS

sec "0. Before recording: goto 1"
prep goto 1
[ "$(main_files)" = ".gitignore,README.md,backend,contracts" ] && ok "main = backend + contract" || bad "main files: $(main_files)"
curl -s $BASE/raw/branch/main/README.md | grep >/dev/null -c "contracts/orders-openapi.yaml" && ok "start README mentions the contract" || bad "start README"
[ -z "$(api_listed)" ] && ok "Backstage has no APIs" || bad "Backstage APIs: $(api_listed)"
[ "$(gw)" = 404 ] && ok "gateway 404 (no routes)" || bad "gateway $(gw)"
[ "$(git -C "$CL" branch --show-current)" = main ] && ok "clone is on main" || bad "clone not on main"
DEMO_CLONE="$CL" "$PREP" preflight | grep >/dev/null -c "^READY: record stage1" && ok "preflight: READY for stage1" || bad "preflight not READY at the start"

sec "1. Stage 1: catalog entry"
take_branch feat/add-catalog-entry
git -C "$CL" diff --name-only main | grep >/dev/null -cx catalog-info.yaml && ok "branch adds catalog-info.yaml" || bad "branch content"
push_branch feat/add-catalog-entry
N=$(open_pr feat/add-catalog-entry "Register the Orders API in the catalog"); sleep 3
[ -z "$(curl -s "${C[@]}" $A/commits/$(head_sha $N)/statuses | python3 -c 'import json,sys; print(len(json.load(sys.stdin)) or "")')" ] && ok "no checks on the stage 1 PR" || bad "stage 1 PR has checks"
merge_pr $N; t0=$SECONDS
for i in $(seq 1 60); do [ "$(api_listed)" = orders-api ] && break; sleep 1; done
[ "$(api_listed)" = orders-api ] && ok "Backstage lists orders-api $((SECONDS-t0))s after the merge, no manual refresh" || bad "API not in Backstage after 60s: $(api_listed)"
[ "$(main_files)" = ".gitignore,README.md,backend,catalog-info.yaml,contracts" ] && ok "main not reseeded by refresh-catalog" || bad "main after refresh: $(main_files)"
snap after1

sec "2a. Stage 2 part 1"
prep_keeps_checkout stage2
take_branch feat/add-spectral-gate
git -C "$CL" diff main -- .gitea/ | grep >/dev/null -c '^+  spectral-openapi-check:' && ok "diff shows the gate" || bad "diff"
push_branch feat/add-spectral-gate
N=$(open_pr feat/add-spectral-gate "Add spectral-openapi-check gate"); ci $N
[ "$CI_STATE" = success ] && has success spectral-openapi-check && ok "spectral green" || bad "2a CI"
merge_pr $N; snap after2a
grep -q "one gate" "$W/snap-after2a/README.md" && ok "README: one gate" || bad "README after 2a"

sec "2b. Stage 2 part 2"
prep_keeps_checkout stage2-red
take_branch feat/orders-server-url
git -C "$CL" diff main -- contracts/ | grep >/dev/null -c '^+.*http://orders.api-peak.com' && ok "diff shows http URL" || bad "diff"
push_branch feat/orders-server-url
N=$(open_pr feat/orders-server-url "Move Orders API to orders.api-peak.com"); ci $N
[ "$CI_STATE" = failure ] && has failure spectral-openapi-check && ok "spectral RED" || bad "expected red"
L=$(job_log spectral-openapi-check)
echo "$L" | grep >/dev/null -c 'api-peak:rest17:2025-https-required' && ok "log: rest17:2025-https-required" || bad "rule id"
echo "$L" | grep >/dev/null -c "$GUIDE/#https-api-peakrest172025-https" && ok "the error links to the rule in the catalog (Backstage TechDocs)" || bad "no catalog link in the Spectral error"
techdocs_has_anchor https-api-peakrest172025-https && ok "the catalog page has that rule's anchor" || bad "anchor missing in TechDocs"
echo "$L" | grep >/dev/null -c '1 problem (1 error, 0 warnings, 0 infos, 0 hints)' && ok "Spectral reports exactly one problem" || bad "Spectral reports more than the rest17 error"
echo "$L" | grep >/dev/null -c 'cloning https://github.com' && bad "CI still downloads from github.com" || ok "no download from github.com (checkout is plain git)"
echo "$L" | grep >/dev/null -cE 'added [0-9]+ packages' && bad "CI still npm-installs Spectral" || ok "Spectral preinstalled in the CI image"
OLD=$(head_sha $N)
sed -i 's#http://orders.api-peak.com#https://orders.api-peak.com#' "$CL/contracts/orders-openapi.yaml"
git -C "$CL" commit -qam "Use HTTPS server URL"; git -C "$CL" push -q 2>&1 | grep -v '^remote'
ci $N "$OLD"; [ "$CI_STATE" = success ] && ok "green after fix" || bad "after fix"
job_log spectral-openapi-check | grep >/dev/null -c 'No results with a severity' && ok "Spectral: no findings on the fixed contract" || bad "Spectral still reports findings"
merge_pr $N; snap after2b

sec "3a. Stage 3 part 1"
prep_keeps_checkout stage3
[ "$(curl -s $MOCK)" = '{"orderId":"123","isPaid":true}' ] && ok "mock serves the contract's example" || bad "mock: $(curl -s $MOCK)"
take_branch feat/add-contract-test-gate
git -C "$CL" diff main -- .gitea/ | grep >/dev/null -c '^+  contract-test:' && ok "diff shows the gate" || bad "diff"
push_branch feat/add-contract-test-gate
N=$(open_pr feat/add-contract-test-gate "Add contract-test gate (Microcks)"); ci $N
[ "$CI_STATE" = success ] && [ "$(n_success)" = 2 ] && ok "two gates green" || bad "3a CI"
merge_pr $N; snap after3a

sec "3b. Stage 3 part 2"
prep_keeps_checkout stage3-red
take_branch feat/orders-currency
git -C "$CL" diff main -- contracts/ | grep >/dev/null -c 'required: \[orderId, isPaid, currency\]' && ok "diff shows required currency" || bad "diff"
push_branch feat/orders-currency
N=$(open_pr feat/orders-currency "Add currency to the order response"); ci $N
[ "$CI_STATE" = failure ] && has failure contract-test && ok "contract-test RED" || bad "expected red"
job_log contract-test | grep >/dev/null -c "currency' not found" && ok "Microcks: currency' not found" || bad "currency message"
has_currency $MOCK && ok "mock (from the PR's contract) returns currency" || bad "mock has no currency"
has_currency http://localhost:8081/orders/123 && bad "backend returns currency?" || ok "running backend doesn't return currency"
OLD=$(head_sha $N)
sed -i 's/required: \[orderId, isPaid, currency\]/required: [orderId, isPaid]/' "$CL/contracts/orders-openapi.yaml"
git -C "$CL" commit -qam "Don't promise currency until the backend returns it"; git -C "$CL" push -q 2>&1 | grep -v '^remote'
ci $N "$OLD"; [ "$CI_STATE" = success ] && ok "green after fix" || bad "after fix"
merge_pr $N; snap after3b

sec "4. Stage 4"
prep_keeps_checkout stage4
[ "$(gw)" = 404 ] && ok "gateway 404 before the PR" || bad "gateway $(gw) before the PR"
take_branch feat/add-gateway-gate
git -C "$CL" diff main -- .gitea/ | grep >/dev/null -c '^+  gateway-deploy-check:' && ok "diff shows the gate" || bad "diff"
push_branch feat/add-gateway-gate
N=$(open_pr feat/add-gateway-gate "Add gateway-deploy-check gate (KrakenD)"); ci $N
[ "$CI_STATE" = success ] && [ "$(n_success)" = 3 ] && ok "three gates green" || bad "4 CI"
L=$(job_log gateway-deploy-check)
echo "$L" | grep >/dev/null -c 'Generated krakend.json' && ok "log: Generated krakend.json" || bad "krakend log"
echo "$L" | grep >/dev/null -cE 'added [0-9]+ packages|krakend.tgz.*100' && bad "CI still downloads gateway tools" || ok "gateway tools preinstalled"
merge_pr $N
G=$(curl -s localhost:8090/orders/123); D=$(curl -s localhost:8081/orders/123)
[ "$(gw)" = 200 ] && [ "$G" = "$D" ] && ok "gateway 200, same body as backend" || bad "gateway '$G' vs backend '$D'"
snap after4

sec "5a. Stage 5 part 1"
prep_keeps_checkout stage5
take_branch feat/add-backwards-compat-gate
git -C "$CL" diff main -- .gitea/ | grep >/dev/null -c '^+  breaking-changes-check:' && ok "diff shows the gate" || bad "diff"
push_branch feat/add-backwards-compat-gate
N=$(open_pr feat/add-backwards-compat-gate "Insert breaking-changes-check between lint and contract-test"); ci $N
[ "$CI_STATE" = success ] && [ "$(n_success)" = 4 ] && ok "four gates green" || bad "5a CI"
merge_pr $N; snap after5a

sec "5b. Stage 5 part 2"
prep_keeps_checkout stage5-red
take_branch feat/orders-require-channel
git -C "$CL" diff main -- contracts/ | grep >/dev/null -c '^+.*name: channel' && ok "diff shows channel" || bad "diff"
push_branch feat/orders-require-channel
N=$(open_pr feat/orders-require-channel "Require sales channel when reading an order"); ci $N
[ "$CI_STATE" = failure ] && has failure breaking-changes-check && has skipped contract-test && has skipped gateway-deploy-check && ok "BC red, 2 skipped" || bad "expected BC red + 2 skipped"
job_log breaking-changes-check | grep >/dev/null -c 'new-required-request-parameter' && ok "oasdiff: new-required-request-parameter" || bad "oasdiff message"
OLD=$(head_sha $N)
sed -i '/name: channel/,/required:/ s/required: true/required: false/' "$CL/contracts/orders-openapi.yaml"
git -C "$CL" commit -qam "Make channel optional (non-breaking)"; git -C "$CL" push -q 2>&1 | grep -v '^remote'
ci $N "$OLD"; [ "$CI_STATE" = success ] && [ "$(n_success)" = 4 ] && ok "all four green after fix" || bad "after fix"
merge_pr $N; snap after5b

sec "6. goto <target> equals the real walk-through"
GC="$W/gclone"
for pair in "2 after1 feat/add-spectral-gate stage2" "2-red after2a feat/orders-server-url stage2-red" \
            "3 after2b feat/add-contract-test-gate stage3" "3-red after3a feat/orders-currency stage3-red" \
            "4 after3b feat/add-gateway-gate stage4" "5 after4 feat/add-backwards-compat-gate stage5" \
            "5-red after5a feat/orders-require-channel stage5-red" "end after5b - -"; do
  set -- $pair
  DEMO_CLONE="$GC" "$PREP" goto "$1" 2>&1 | grep -E "rror|refus|never|should|cannot"
  snap "goto-$1"
  diff -r "$W/snap-$2" "$W/snap-goto-$1" >/dev/null && ok "goto $1 == state after '$2'" || bad "goto $1 differs from '$2'"
  DEMO_CLONE="$GC" "$PREP" preflight | grep >/dev/null -c "^READY" && ok "preflight READY after goto $1" || bad "preflight NOT READY after goto $1"
  case "$1" in 3-red) ! has_currency $MOCK && ok "goto 3-red: mock without currency" || bad "goto 3-red: mock still has currency" ;;
               4)     has_currency $MOCK && ok "goto 4: mock with currency (optional)" || bad "goto 4: mock lacks currency" ;; esac
  if [ "$3" != - ]; then
    git -C "$GC" show-ref --verify -q "refs/heads/$3" && ! on_remote "$3" && ok "goto $1: $3 local only" || bad "goto $1: branch $3 not local-only"
    st=$(DEMO_CLONE="$GC" "$PREP" status 2>&1)
    echo "$st" | grep >/dev/null -c "^Next: $4, branch $3." && echo "$st" | grep >/dev/null -c "already prepared" && ok "status after goto $1: next is $4, already prepared" || bad "status after goto $1: $st"
  else
    DEMO_CLONE="$GC" "$PREP" status 2>&1 | grep >/dev/null -c "Everything is merged" && ok "status after goto end: everything merged" || bad "status after goto end"
  fi
done

sec "7. Invariants"
[ "$SEED0" = "$(seed_started)" ] && ok "gitea-seed never re-ran" || bad "gitea-seed re-ran"
DEMO_CLONE="$GC" "$PREP" goto bogus >/dev/null 2>&1 && bad "goto bogus should fail" || ok "goto with unknown target fails"
mkdir -p "$W/notaclone"; DEMO_CLONE="$W/notaclone" "$PREP" goto 1 >/dev/null 2>&1 && bad "goto replaced a non-clone folder" || ok "goto refuses to replace a folder that isn't a demo clone"

echo; echo "================ RESULT: $PASS passed, $FAIL failed ($((SECONDS-T0))s) ================"
echo "The demo state is now 'end'. Run: scripts/demo/prep-stage.sh goto 1"
[ $FAIL = 0 ]
