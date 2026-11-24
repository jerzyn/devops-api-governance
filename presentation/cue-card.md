# Cue card — recording the demo

One page to keep next to the recording. Every step is **one PR in the orders repo** that governs both APIs: the Orders API (REST, `contracts/orders-openapi.yaml`) and the Order Events API (MQTT, `contracts/order-events-asyncapi.yaml`). Each PR runs two workflows, **PR API governance (REST)** and **PR API governance (events)**, with the same gates. The Kafka repo comes after step 5.

**T2** = off-camera terminal (any directory). `demo <Tab>` completes; `demo help` lists everything. One-time: `~/projekty/devops-api-governance/scripts/demo/demo install`, new terminal. **T1** = recorded terminal. **PR** = `http://localhost:3000/governance-demo/devops-api-governance/compare/main...<branch>` → **New Pull Request** → **Create Pull Request**. Merging: **Create merge commit**.

## Before pressing record
```bash
# T2
demo fresh           # final take only: PRs start at #1 (asks first)
demo goto 1          # dry run / retake: back to the Stage 1 start
demo preflight       # must end with READY
# T1
demo shell
```
Browser: signed in to Gitea (`demo`/`demo12345`). Tabs: Gitea repo home, Backstage **APIs**. Zoom ~125–150%.

**Between steps (T2), after each merge:** `demo next`.
**Take went wrong:** `demo goto <1|2|2-red|3|3-red|4|5|5-red|kafka|end>` (first waits for the aborted take's CI to finish) → `demo shell` again in T1.

---

## 1 · Catalog — "You can't govern what you can't see."
```bash
ls contracts/
git switch feat/add-catalog-entry
vi catalog-info.yaml     # :q to close
git push -u origin feat/add-catalog-entry
```
PR (no checks) → **Merge** → Backstage tab → reload **APIs** → `orders-api` (openapi) and `order-events-api` (asyncapi), both at once (~10 s) → **Definition** of each → `order-events-api` **Dependencies**: producer, consumer, broker.

## 2 · Guidelines — "A guideline nobody enforces is a suggestion."
**2a** (`next` done)
```bash
git switch feat/add-lint-gates
git diff --stat main
git push -u origin feat/add-lint-gates
```
PR → **Files changed** (two workflows, one lint gate each) → while CI runs: Backstage → **Docs** → `api-guidelines`, scroll: REST, then the async and MQTT rules → back, both green → **Merge**. T2: `next`.

**2b**
```bash
git switch feat/orders-server-and-paid-at
git diff main -- contracts/
git push -u origin feat/orders-server-and-paid-at
```
PR → **both red** → **Details** of `openlint-openapi-check`: `rest17:2025-https-required` → **Details** of `asyncapi-lint`: `async11:2026-property-naming … 'paid_at' MUST be camelCase`. Open a link → the rule in Backstage. *"One set of guidelines, for REST and events, for humans and CI."*
```bash
sed -i 's#http://orders.api-peak.com#https://orders.api-peak.com#' contracts/orders-openapi.yaml
sed -i 's/^        paid_at:$/        paidAt:/' contracts/order-events-asyncapi.yaml
git diff
git commit -am "Use HTTPS, name it paidAt"
git push origin feat/orders-server-and-paid-at
```
Both green → **Merge**. T2: `next`.

## 3 · Mocks & contract test — "A contract is a promise."
**3a**
```bash
git switch feat/add-contract-test-gates
git diff --stat main
git push -u origin feat/add-contract-test-gates
```
PR → **Files changed** → both green (cut) → **Merge**. Then:
```bash
curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123    # live REST mock from the contract
```
```bash
curl -sN -u observer:observer-pw "mqtt://localhost:1883/OrderEventsAPI-1.0.0-orders%2Fv1%2F%7BorderId%7D%2Fcreated" | tr -c '[:print:]' '\n'   # MQTT mock events, Ctrl+C
```
Microcks → **Order Events API**: the mock events from the contract's examples. *"Partners and consumers integrate today, before the code exists."* T2: `next`.

**3b**
```bash
git switch feat/orders-currency
git diff main -- contracts/
git push -u origin feat/orders-currency
```
PR → lint green, **both contract-test red** → **Details** (REST): `currency' not found` · **Details** (events): `required property 'currency' not found` (5 of 5 messages).
```bash
curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123    # mock: has currency
curl -s http://localhost:8081/orders/123                          # backend: doesn't
```
*"We don't promise what the code doesn't deliver yet."*
```bash
sed -i 's/required: \[orderId, isPaid, currency\]/required: [orderId, isPaid]/' contracts/orders-openapi.yaml
sed -i 's/required: \[orderId, createdAt, currency\]/required: [orderId, createdAt]/' contracts/order-events-asyncapi.yaml
git diff
git commit -am "Don't promise currency until the backends send it"
git push origin feat/orders-currency
```
Both green → **Merge**. T2: `next`.

## 4 · Deploy from the contract — "Expose it for real, generated from the contract."
```bash
curl -i http://localhost:8090/orders/123                          # 404: no routes yet
git switch feat/add-deploy-gates
git diff --stat main
git push -u origin feat/add-deploy-gates
```
PR → **Files changed** → 3 gates each → **Details** `gateway-deploy-check`: **Generate krakend.json…**, **Deploy…**, **Run contract test through the gateway** · **Details** `broker-policy`: the generated policy, the checks from the outside → green → **Merge**.
```bash
curl -i http://localhost:8090/orders/123                          # 200, through KrakenD
demo deny                                                         # the broker says no to what the contract doesn't grant
```
(slides: ACL animation) T2: `next`.

## 5 · Breaking changes — "A partner is integrated now."
**5a**
```bash
git switch feat/add-breaking-changes-gates
git diff --stat main
git push -u origin feat/add-breaking-changes-gates
```
PR → **Files changed** (a new job in the middle of each workflow, repointed `needs:`) → all green (cut) → **Merge** → Actions: **Publish event API (main)** registers the schemas.
*"Right after lint, before the runtime tests."* T2: `next`.

**5b**
```bash
git switch feat/orders-channel-and-is-paid
git diff main -- contracts/
git push -u origin feat/orders-channel-and-is-paid
```
PR → **both breaking-changes red**, the later gates **Skipped** (wait until they turn grey) → **Details** REST: `new-required-request-parameter … channel` · **Details** events: `not FORWARD-compatible` (consumers still read `isPaid`).
```bash
sed -i '/name: channel/,/required:/ s/required: true/required: false/' contracts/orders-openapi.yaml
git checkout main -- contracts/order-events-asyncapi.yaml
sed -i '/^        isPaid:$/{n;s/$/\n          deprecated: true/}' contracts/order-events-asyncapi.yaml
git diff
git commit -am "Make channel optional, deprecate isPaid instead of removing it"
git push origin feat/orders-channel-and-is-paid
```
All green (full speed, the climax) → **Merge**. T2: `next`.

## Same gates on Kafka (optional)
```bash
DEMO_SHELL_REPO=kafka demo shell
git switch feat/kafka-paid-at
git push -u origin feat/kafka-paid-at
```
Kafka repo PR (its `catalog-info.yaml` and an optional `paidAt`) → all four gates green → **Merge** → Backstage: `order-events-kafka-api` joins the other two. T2: `next`.
```bash
git switch feat/kafka-drop-is-paid
git push -u origin feat/kafka-drop-is-paid
```
PR → red: `orders.order-paid.v1 … not FORWARD-compatible`. End.

---

If CI fails before any step ran (`connection reset…`): **Re-run**, or `git commit --allow-empty -m retry && git push`.
