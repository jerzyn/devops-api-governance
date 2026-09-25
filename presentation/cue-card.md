# Cue card — recording the demo

One page to keep next to the recording. The full explanations are in `screenplay.md`.

**T2** = off-camera terminal in `~/projekty/devops-api-governance`. **T1** = recorded terminal. **PR** = `http://localhost:3000/governance-demo/devops-api-governance/compare/main...<branch>` → **New Pull Request** → **Create Pull Request**.

## Before pressing record
```bash
# T2
scripts/demo/fresh-gitea.sh          # final take only: PRs start at #1 (asks first)
scripts/demo/prep-stage.sh goto 1    # dry run / retake: back to the Stage 1 start
scripts/demo/prep-stage.sh preflight # must end with READY
# T1
source ~/projekty/devops-api-governance/scripts/demo/demo-shell.sh
```
Browser: signed in to Gitea (`demo`/`demo12345`). Tabs: Gitea repo home, Backstage **APIs**. Zoom ~125–150%.

**Between steps (T2), after each merge:** `scripts/demo/prep-stage.sh next`.
**Take went wrong:** `scripts/demo/prep-stage.sh goto <1|2|2-red|3|3-red|4|5|5-red>` (first waits up to ~1–2 min for the aborted take's CI to finish) → re-source `demo-shell.sh` in T1.

---

## 1 · Catalog — "You can't govern what you can't see."
```bash
ls
git switch feat/add-catalog-entry
cat catalog-info.yaml
git push -u origin feat/add-catalog-entry
```
PR (no checks) → **Merge** → Backstage tab → reload **APIs** → `orders-api` (~10 s) → **Definition** tab.

## 2 · Spectral — "A guideline nobody enforces is a suggestion."
**2a** (`next` done)
```bash
git switch feat/add-spectral-gate
git diff --stat main
git push -u origin feat/add-spectral-gate
```
PR → **Files changed** → green (cut the wait) → **Merge**. T2: `next`.

**2b**
```bash
git switch feat/orders-server-url
git diff main -- contracts/
git push -u origin feat/orders-server-url
```
PR → **red** → **Details** → **Run Spectral (fail on errors)**: `rest17:2025-https-required`, `1 problem`.
Open the link under the error → rule in Backstage. *"Same rule for humans and CI, one source of truth."*
```bash
sed -i 's#http://orders.api-peak.com#https://orders.api-peak.com#' contracts/orders-openapi.yaml
git commit -am "Use HTTPS server URL" && git push
```
Green → **Merge**. T2: `next`.

## 3 · Mocks & contract test — "A contract is a promise."
**3a**
```bash
git switch feat/add-contract-test-gate
git diff --stat main
git push -u origin feat/add-contract-test-gate
```
PR → **Files changed** → green (cut) → **Merge**. Then:
```bash
curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123    # live mock from the contract
```
*"Partners integrate today, before the code exists."* T2: `next`.

**3b**
```bash
git switch feat/orders-currency
git diff main -- contracts/
git push -u origin feat/orders-currency
```
PR → spectral green, **contract-test red** → **Details** → **Run contract test**: `currency' not found`.
```bash
curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123    # mock: has currency
curl -s http://localhost:8081/orders/123                          # backend: doesn't
```
*"We don't promise what the code doesn't deliver yet."*
```bash
sed -i 's/required: \[orderId, isPaid, currency\]/required: [orderId, isPaid]/' contracts/orders-openapi.yaml
git commit -am "Don't promise currency until the backend returns it" && git push
```
Green → **Merge**. T2: `next`.

## 4 · Gateway — "Expose it for real, generated from the contract."
```bash
curl -i http://localhost:8090/orders/123                          # 404: no routes yet
git switch feat/add-gateway-gate
git diff --stat main
git push -u origin feat/add-gateway-gate
```
PR → **Files changed** → 3 gates → **Details** gateway-deploy-check: **Generate krakend.json…**, **Deploy…**, **Run contract test through the gateway** → green → **Merge**.
```bash
curl -i http://localhost:8090/orders/123                          # 200, through KrakenD
curl -s http://localhost:8081/orders/123                          # same body
```
T2: `next`.

## 5 · Backwards compatibility — "A partner is integrated now."
**5a**
```bash
git switch feat/add-backwards-compat-gate
git diff --stat main
git push -u origin feat/add-backwards-compat-gate
```
PR → **Files changed** (new job in the middle, repointed `needs:`) → 4 gates green (cut) → **Merge**.
*"Right after lint, before the runtime tests."* T2: `next`.

**5b**
```bash
git switch feat/orders-require-channel
git diff main -- contracts/
git push -u origin feat/orders-require-channel
```
PR → **breaking-changes-check red**, the other two **Skipped** (wait until they turn grey) → **Details** → **Run oasdiff breaking…**: `new-required-request-parameter … channel`.
```bash
sed -i '/name: channel/,/required:/ s/required: true/required: false/' contracts/orders-openapi.yaml
git commit -am "Make channel optional (non-breaking)" && git push
```
All four green (full speed, the climax) → **Merge**.

---

If CI fails before any step ran (`connection reset…`): **Re-run**, or `git commit --allow-empty -m retry && git push`.
