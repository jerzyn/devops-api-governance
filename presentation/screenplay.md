# Screenplay: DevOps API Governance, built up gate by gate

The demo grows a delivery pipeline one gate at a time, in five steps. Every step is **one pull request in the orders repo** that governs both of its APIs at once:

- the **Orders API**, REST, `contracts/orders-openapi.yaml`;
- the **Order Events API**, events on MQTT, `contracts/order-events-asyncapi.yaml`.

Each PR runs two workflows with the same gates: **PR API governance (REST)** and **PR API governance (events)**. After step 5, the same gates run on the Kafka version of the event API, in a repo of its own.

Two parts happen in every step:
- **Terminal:** git commands in the demo clone of the Gitea repo.
- **Browser:** Gitea (PR, changed files, CI logs), Backstage, Microcks. Every browser step below is a click-path, so you can run the whole demo alone, live or recorded.

Between steps there is one off-camera command, always the same: `demo next`.

**The `demo` command** wraps every script in `scripts/demo/` and completes with Tab (`demo <Tab>`, `demo goto <Tab>`). One-time setup, from the root of this repo: `scripts/demo/demo install` (adds one line to `~/.bashrc`), then open a new terminal. `demo help` lists everything. It works from any directory.

**While presenting, use [`cue-card.md`](cue-card.md)**: the same steps on one page (commands, clicks, one line to say). This file explains them.

## Run of show

| Step | Adds | REST · what the audience should remember | Events · what the audience should remember |
|---|---|---|---|
| 1 | Catalog | Merge one `catalog-info.yaml`: `orders-api` appears in Backstage by itself. No CI yet. | `order-events-api` appears at the same moment, rendered as AsyncAPI, with its producer, consumer and broker. |
| 2 | Guidelines (OpenLint) | `api-peak:rest17:2025-https-required` goes red, its link opens the rule in Backstage. | `api-peak:async11:2026-property-naming`: `paid_at` MUST be camelCase. One fix commit turns both green. |
| 3 | Mocks + contract test (Microcks) | The contract is a live mock; then it promises a `currency` the backend doesn't send: `currency' not found`. | Microcks listens on the broker: `required property 'currency' not found` in every message. Both backends send it, green. |
| 4 | Deploy from the contract | KrakenD config generated from the contract: `curl` goes from 404 to 200. | Broker policy generated from the contract and the catalog; `demo deny` shows the broker refusing the rest. |
| 5 | Breaking changes | oasdiff: `new-required-request-parameter`, the later gates are skipped. `channel` becomes optional. | The schema registry: removing `isPaid` is not FORWARD-compatible. Deprecating it instead passes. |
| Kafka | Same gates, other broker | (none) | An optional field passes all four gates on Kafka; removing `isPaid` is red there too. |

## How every step works

Steps 2, 3 and 5 have two parts. **Part 1** installs the new gates. **Part 2** is the real shot: the gates catch a bad change (red, fix, green). Steps 1 and 4 have a single part.

1. **Prep (off camera):** `demo next`. It reads Gitea `main`, works out which step comes next and creates that step's branch **in your demo clone**, committed but **not pushed**. It first brings the clone's `main` up to Gitea `main`, and it doesn't touch what your terminal has checked out, so you can run it while the presenting terminal sits in the clone. Nothing is typed from scratch, and the red states are red every time. Run it after the previous PR is merged (it tells you if you are too early). After a `goto`, the next branch is already there.
2. **Terminal, show and push:** `git switch <branch>`, show the change, then `git push -u origin <branch>`.
   - Contract changes are a few lines: show them with `git diff main -- contracts/`.
   - Workflow changes are long YAML: in the terminal only `git diff --stat main`, and the change itself in the PR's **Files changed** tab, where it is readable.
3. **Browser, PR and checks:** open the PR (`compare/main...<branch>` → **New Pull Request** → **Create Pull Request**). Both workflows start. Open a check's **Details** for the one log line that matters (each step names it).
4. **Terminal, fix (red parts only):** edit the files in `vi` at the line the cue card gives, `git diff`, `git commit -am`, `git push`. The push updates the same PR, so the checks re-run and go from red to green.
5. **Browser, merge:** **Create merge commit**. `main` of both consumer repos is protected from step 2 on: Gitea allows the merge only when every check is green.

**Part 1 is short on purpose.** A PR that only adds workflows has nothing for the new gates to find, so its green checks say little. Show what is added (**Files changed**), let the checks start, cut or talk over the wait, merge. Spend the time on part 2.

Three things to keep in mind:
- Keep the same clone (`~/demo/orders-api`, Kafka: `~/demo/order-events-kafka-api`) for the whole walk-through. `next` adds each branch to it. `goto` replaces it with a fresh one.
- A `git push` does not open a PR in Gitea (the "Create a new pull request" line it prints is only a hint). PRs are always opened in the browser.
- `git diff main` is right because `next` updates your local `main` to Gitea `main` just before creating the branch. No `git fetch` or `origin/main` on screen.

If a step goes wrong, don't redo the earlier steps: use `demo goto <target>` (see "Retakes").

---

## Before you start

1. **Stack up** with all five profiles (see the appendix).
2. **For the final run only: `demo fresh`.** It wipes the demo Gitea (all PRs, CI runs and branches from rehearsals), brings the stack up again and runs `goto 1`. PR numbers then start at #1 and the Actions tab is empty. It asks before deleting anything. For a dry run, `demo goto 1` is enough.
3. `demo goto 1` (if you didn't run `demo fresh`): Gitea `main` of both consumer repos goes back to the step 1 start, open PRs are closed, all `feat/*` branches on Gitea are deleted, the governance repo is synced, the Backstage catalog is cleared, the gateway has no routes, the broker policy, the schema registry and the Microcks mocks match `main`, and **fresh demo clones** are made with the step 1 branch in them (not pushed).
4. In the browser, **sign in to Gitea** at `http://localhost:3000/user/login` as `demo` / `demo12345`. Without a login the PR page has no create or merge buttons. If Backstage shows a sign-in page, sign in as guest once.
5. In the presenting terminal: `demo shell`. It `cd`s into the clone, sets a short prompt with the current branch (`orders (main) $`), pages long output only when it doesn't fit, and clears the screen.
6. Check: `demo preflight` in the second terminal. It checks the stack, the runner and CI image, Gitea, Backstage, the gateway, the mocks, the broker, the registry, the guidelines page, CI still running from an earlier take, and the demo clones. It ends with `READY` or a list of problems with the command that fixes each. Run it before every take.

The Gitea repo has the same name as this project (`devops-api-governance`), so never clone it under that name or inside the project directory: a `rm -rf` of that name could delete the project. `~/demo/orders-api` can't be confused with it, and `goto` only ever deletes a folder that is a clone of the demo repo.

## Screen layout and windows

Have everything below open **before** you start, so no step begins with a blank browser or a login screen.

- **Screen:** terminal on the left, browser on the right. Terminal font ~18–20 pt and browser zoom ~125–150% (`Ctrl` `+`), so it is readable on a projector.
- **Terminal 1 (shown):** after `demo shell`, in the demo clone. Only git, `vi`, `curl` and `demo deny` run here. `clear` before each step.
- **Terminal 2 (not shown):** any directory, only for `demo next`, `preflight` and `goto`. Keep it off the shared screen.
- **Browser:** one window, signed in to Gitea. Tabs: the Gitea repo home and Backstage **APIs**; Microcks (`localhost:8080`) only in step 3. Bookmarks bar hidden.
- **Not running / not visible:** desktop notifications, other windows.

## Retakes: roll back to any step

`demo goto <target>` puts Gitea `main` of both consumer repos, the Backstage catalog, the KrakenD gateway, the Microcks mocks, the schema registry and the broker policy in the state right **before** that step. It replays every earlier step's changes onto `main` (including the merged fixes), closes open PRs, deletes all `feat/*` branches on Gitea, builds the guidelines page in Backstage (so it never shows "building" on screen), makes fresh demo clones and prepares the branch of the step you are about to show (local, not pushed). If an aborted take's CI is still running, `goto` first waits for it to finish (a late job would redeploy the gateway or reload a mock after the reset).

| Target | Already merged on `main` | Branch prepared in the clone |
|---|---|---|
| `goto 1` | nothing: both contracts and the backends, no catalog entry, no workflows | `feat/add-catalog-entry` |
| `goto 2` | step 1 (both APIs in Backstage) | `feat/add-lint-gates` |
| `goto 2-red` | + both lint gates | `feat/orders-server-and-paid-at` |
| `goto 3` | + step 2 fix (`https://orders.api-peak.com`, `paidAt`) | `feat/add-contract-test-gates` |
| `goto 3-red` | + both contract-test gates | `feat/orders-currency` |
| `goto 4` | + step 3 fix (`currency` required, both backends send it) | `feat/add-deploy-gates` |
| `goto 5` | + gateway and broker-policy gates | `feat/add-breaking-changes-gates` |
| `goto 5-red` | + both breaking-changes gates, `main-publish.yml` | `feat/orders-channel-and-is-paid` |
| `goto kafka` | + step 5 fix (optional `channel`, deprecated `isPaid`) | `feat/kafka-paid-at` (Kafka repo) |
| `goto end` | Kafka repo: + catalog entry, `paidAt` | `feat/kafka-drop-is-paid` (Kafka repo) |

After a `goto`, run `demo shell` again if your terminal was inside the old clone. `demo status` tells you where you are at any time. If `git switch` says `fatal: invalid reference: feat/...`, the branch isn't prepared yet: run `demo next`.

## Browser cheat sheet

Repo: `http://localhost:3000/governance-demo/devops-api-governance`

- **Open a PR:** `<repo>/compare/main...<branch>` → **New Pull Request** → **Create Pull Request**. The title is prefilled from the branch's commit.
- **Show the change:** the PR's **Files changed** tab.
- **Watch the checks:** listed on the PR's **Conversation** tab, one group per workflow (REST, events). The list updates by itself; reload if it looks stuck.
- **Read a job's log:** **Details** next to a check, then click a step row to expand it.
- **Merge:** when all checks are green, **Create merge commit** at the bottom of the Conversation tab, then confirm.
- **Backstage:** `http://localhost:7007`. Left menu **APIs**, then the API's name.
- **API guidelines in the catalog:** `http://localhost:7007/docs/default/component/api-guidelines` (Backstage → **Docs** → `api-guidelines`). Sidebar: General, REST, Async (MQTT, Kafka). Every lint error links to its rule.
- **Microcks:** `http://localhost:8080`. Test reports are linked from the CI logs (`http://localhost:8080/#/tests/…`).
- **Apicurio Registry:** `http://localhost:8280`, group `order-events-api`.

---

## Step 1: Catalog

**Say:** "You can't govern what you can't see. One file makes both APIs visible to the whole organization."

**Starting state:** Gitea `main` has both contracts, `backend/`, `events-backend/` and `events-subscriber/`. No `catalog-info.yaml`, no workflow. Backstage lists no order APIs.

**Terminal:**
```bash
ls contracts/                                    # orders-openapi.yaml, order-events-asyncapi.yaml
git switch feat/add-catalog-entry
vi catalog-info.yaml                             # both APIs, their providers, the subscriber, the broker (:q to close)
git push -u origin feat/add-catalog-entry
```

**Browser:**
1. Open the PR. There are no checks, so it is mergeable at once. Merge.
2. Backstage **APIs**, reload: `orders-api` (openapi) and `order-events-api` (asyncapi) appear together within ~10 s (Backstage rescans Gitea every 10 s).
3. **Definition** of each: the rendered OpenAPI, then channels, operations, messages and MQTT bindings.
4. `order-events-api` → **Dependencies** (or the Catalog Graph): `orders-backend` provides it, `orders-subscriber` consumes it, both depend on `mqtt-broker`.

---

## Step 2: Guidelines as code

**Say:** "A guideline nobody enforces is a suggestion."

**Part 1: install the gates.** Branch `feat/add-lint-gates` adds the two PR workflows, each with one lint gate: `openlint-openapi-check` (REST) and `asyncapi-lint` (events, with the ruleset for the contract's protocol).

```bash
git switch feat/add-lint-gates
git diff --stat main                             # two new workflows (and the README)
git push -u origin feat/add-lint-gates
```

1. Open the PR → **Files changed**: two workflows, one lint gate each, both cloning the central governance repo for the rules.
2. While CI runs: Backstage → **Docs** → `api-guidelines`, click through the sidebar (General, REST, Async with MQTT and Kafka): these are the rules the gates enforce.
3. Back on the PR, both checks go green. Merge. T2: `demo next`.

**Part 2: the gates catch something.** Branch `feat/orders-server-and-paid-at`: the REST server URL moves to `http://orders.api-peak.com`, and `OrderPaid` gets an optional `paid_at`.

```bash
git switch feat/orders-server-and-paid-at
git diff main -- contracts/
git push -u origin feat/orders-server-and-paid-at
```

1. Open the PR. **Both lint checks go red**, and **Merge** is blocked.
2. **Details** of `openlint-openapi-check` → **Run OpenLint (fail on errors)**:
   ```
   27:10  error  api-peak:rest17:2025-https-required  server.url MUST use HTTPS.
    http://localhost:7007/docs/default/component/api-guidelines/rest/#https-api-peakrest172025-https
   ```
3. **Details** of `asyncapi-lint` → **Lint against the API guidelines (fail on errors)**:
   ```
   134:17  error  api-peak:async11:2026-property-naming  Property 'paid_at' MUST be camelCase.
    http://localhost:7007/docs/default/component/api-guidelines/async/#property-naming-api-peakasync112026-property-naming
   ```
4. Open one of the links: Backstage opens the guideline at that rule. Say: "One set of guidelines, for REST and events, for humans and for CI."

**Terminal (fix):**
```bash
vi +27 contracts/orders-openapi.yaml             # http://orders.api-peak.com -> https://orders.api-peak.com
vi +134 contracts/order-events-asyncapi.yaml     # paid_at: -> paidAt:
git diff
git commit -am "Use HTTPS, name it paidAt"
git push origin feat/orders-server-and-paid-at
```

**Browser:** both checks re-run and go green. Merge. T2: `demo next`.

---

## Step 3: Mocks and contract testing

**Say:** "A contract is a promise. Partners get a live mock at once, and CI proves the running code keeps the promise."

**Part 1: install the gates.** Branch `feat/add-contract-test-gates` adds a `contract-test` job after lint in both workflows. The REST one tests the running backend over HTTP; the event one deploys the PR's `events-backend/`, then Microcks listens on the broker and checks every event it receives.

```bash
git switch feat/add-contract-test-gates
git diff --stat main
git push -u origin feat/add-contract-test-gates
```

1. Open the PR → **Files changed** → both workflows green (cut or talk over the wait). Merge.
2. **The contract is a live mock.** Partners and consumers can integrate today:
   ```bash
   curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123
   # {"orderId":"123","isPaid":true}
   curl -sN -u observer:observer-pw "mqtt://localhost:1883/OrderEventsAPI-1.0.0-orders%2Fv1%2F%7BorderId%7D%2Fcreated" | tr -c '[:print:]' '\n'
   # the contract's example event, every few seconds; Ctrl+C
   ```
3. Microcks → **Order Events API**: the mock events come from the contract's examples. T2: `demo next`.

**Part 2: the contract promises more than the code delivers.** Branch `feat/orders-currency` makes `currency` **required** in the order response and in `OrderCreated`. Neither backend sends it.

```bash
git switch feat/orders-currency
git diff main -- contracts/
git push -u origin feat/orders-currency
```

1. Open the PR. Lint is green, **both contract tests go red**.
2. **Details** (REST) → **Run contract test**: `currency' not found`.
3. **Details** (events) → **Run contract test (fail on any invalid or missing event)**:
   ```
   FAIL  SEND sendOrderCreated  on orders/v1/+/created  (5 messages, 5 invalid)
         required property 'currency' not found
   PASS  SEND sendOrderPaid  on orders/v1/+/paid  (5 messages, 0 invalid)
   ```
   Optional: open the report link in Microcks.
4. Show the difference the red check is about:
   ```bash
   curl -s http://localhost:8080/rest/Orders+API/1.0.0/orders/123   # mock, from the PR's contract: has currency
   curl -s http://localhost:8081/orders/123                         # running backend: doesn't
   ```

**Terminal (fix):** say "We don't weaken the promise, we make the code keep it." Both backends send the currency; the contracts stay as they are.
```bash
vi +55 backend/server.js                         # isPaid: true,  ->  isPaid: true, currency: "PLN",
vi +33 events-backend/server.js                  # add currency: "PLN" to the OrderCreated payload
git diff
git commit -am "Send the currency the contract promises"
git push origin feat/orders-currency
```

**Browser:** both contract tests run again. Their first step, **Deploy the PR's backend**, puts the PR's code into the running backends, so Microcks tests this PR's code. Both green. Merge.
```bash
curl -s http://localhost:8081/orders/123         # {"orderId":"123","isPaid":true,"currency":"PLN"}
```
T2: `demo next`.

---

## Step 4: Deploy from the contract

**Say:** "Expose it for real, generated from the contract, not written by hand."

Branch `feat/add-deploy-gates` adds `gateway-deploy-check` to the REST workflow and `broker-policy` to the event one, each after the contract test.

```bash
curl -i http://localhost:8090/orders/123         # before: the gateway has no routes, 404
git switch feat/add-deploy-gates
git diff --stat main
git push -u origin feat/add-deploy-gates
```

1. Open the PR → **Files changed**: three gates in each workflow now.
2. **Details** of `gateway-deploy-check`: **Generate krakend.json from the PR contract**, **Deploy to the running gateway**, **Run contract test through the gateway**.
3. **Details** of `broker-policy`: **Generate the broker policy from the contract and the catalog** shows `orders-backend` may publish `orders/v1/+/created` and `orders/v1/+/paid`, and `orders-subscriber` may subscribe to exactly those. Then **Apply it to the broker**, **Check the live policy from the outside**, and the contract test passing again under the new policy.
4. Both green. Merge.

**Terminal (proof it's live):**
```bash
curl -i http://localhost:8090/orders/123         # after: 200 through KrakenD, same body as the backend
curl -v -sN -u orders-subscriber:orders-subscriber-pw "mqtt://localhost:1883/orders%2Fv1%2F%2B%2Fcreated" | tr -c '[:print:]\n' '\n'
                                                 # the catalog's consumer may read; Ctrl+C
demo deny                                        # the broker says no to what the contract doesn't grant
```
`demo deny` prints:
```
A consumer asks for a topic the contract does not have:
  All subscription requests were denied.
... or for more than the contract gives it:
  All subscription requests were denied.
... or connects without an account:
  Connection error: Connection Refused: not authorised.
On Kafka, a topic the contract does not have:
  Topic authorization failed for topics [orders.not-in-contract.v1]
```
In the talk, the ACL animation follows ([`events/acl-animation.html`](events/acl-animation.html), Space to step). T2: `demo next`.

Off-camera note: the policy also lets the platform's `observer` account read every topic (for demos and debugging) and Microcks publish its mock topics. Everything else is denied.

---

## Step 5: Breaking changes

**Say:** "A partner is integrated now. An innocent-looking change would break them."

**Part 1: install the gates.** Branch `feat/add-breaking-changes-gates` inserts a breaking-changes job **between** lint and the contract test in both workflows (`breaking-changes-check` with oasdiff for REST, `breaking-changes` with `@asyncapi/diff` and the schema registry for events) and repoints `needs:`. It also adds `main-publish.yml`, which registers the event payload schemas after each merge.

```bash
git switch feat/add-breaking-changes-gates
git diff --stat main
git push -u origin feat/add-breaking-changes-gates
```

1. Open the PR → **Files changed**: the new job in the middle of each workflow, the repointed `needs:`.
2. All gates green (cut the wait). Merge. Actions: **Publish event API (main)** registers `main`'s schemas in Apicurio.
3. Say: "Right after lint, before the runtime tests. A change that breaks clients shouldn't even reach them." T2: `demo next`.

**Part 2: the gates catch a breaking change.** Branch `feat/orders-channel-and-is-paid`: a new **required** query parameter `channel` on `GET /orders/{orderId}`, and `isPaid` removed from `OrderPaid`, which consumers still read.

```bash
git switch feat/orders-channel-and-is-paid
git diff main -- contracts/
git push -u origin feat/orders-channel-and-is-paid
```

1. Open the PR. Lint is green, **both breaking-changes checks go red**, and the later gates show as **Skipped** (grey). For a few seconds they read "Blocked by required conditions" first: wait until they turn grey, then point at them.
2. **Details** REST → **Run oasdiff breaking (fail on breaking changes)**: `error [new-required-request-parameter] … added the new required query request parameter channel`.
3. **Details** events → **Payloads against the schema registry (dry run)**:
   ```
   FAIL  orders/v1/{orderId}/paid (OrderPaid): not FORWARD-compatible with the registered schema
         consumers built on the registered schema could not read what the API would now send
   ```
   The structural diff before it is clean: same topics, same operations.

**Terminal (fix):** make the change on purpose, not by accident.
```bash
vi +52 contracts/orders-openapi.yaml             # under "- name: channel": required: true -> required: false
git checkout main -- contracts/order-events-asyncapi.yaml    # isPaid back
vi +137 contracts/order-events-asyncapi.yaml     # after "type: boolean" under isPaid: add "deprecated: true"
git diff
git commit -am "Make channel optional, deprecate isPaid instead of removing it"
git push origin feat/orders-channel-and-is-paid
```

**Browser:** all gates run and go green. This is the climax: keep it at full speed. Merge. T2: `demo next`.

---

## The same gates on Kafka (optional)

**Say:** "Same API, on Kafka. Same gates, same scripts; only the broker differs."

```bash
DEMO_SHELL_REPO=kafka demo shell                 # into ~/demo/order-events-kafka-api
git switch feat/kafka-paid-at
git diff main -- contracts/                      # optional paidAt
git push -u origin feat/kafka-paid-at
```

1. Open the PR in the Kafka repo: its `catalog-info.yaml` and an optional `paidAt`. All four gates green. In the logs: lint picked `asyncapi-kafka-ruleset.yaml`, the contract test listened on Kafka, the broker policy reconciled topics and ACLs. Merge.
2. Backstage: `order-events-kafka-api` joins the other two, with the Kafka cluster and the schema registry as Resources. T2: `demo next`.
3. ```bash
   git switch feat/kafka-drop-is-paid
   git push -u origin feat/kafka-drop-is-paid
   ```
   PR: `breaking-changes` **red**, `orders.order-paid.v1 (OrderPaid): not FORWARD-compatible`. Don't merge: end of the demo.

---

## Appendix: operator notes (off camera)

**Stack:** from the root of this repo, all five profiles (see the main README for Podman):
```bash
docker compose --profile contract --profile catalog --profile gateway --profile events --profile kafka up -d
```
Endpoints: Gitea `localhost:3000` (`demo`/`demo12345`), Backstage `:7007`, Microcks `:8080`, REST backend `:8081`, KrakenD `:8090`, MQTT `:1883`, Apicurio `:8280`.

**Run `demo goto 1` after every `up`.** The one-shot `gitea-seed` service force-pushes the template repos over Gitea `main`, which wipes the step state (`demo status` then says it matches no demo state). `backstage` and `gitea-runner` depend on it, so never `up`, `start` or `restart` them mid-demo.

**CI runs offline.** Jobs run in `localhost/devops-api-governance-ci:latest` (`ci-image/Dockerfile`, built by the `ci-image` compose service), which has OpenLint, oasdiff, the KrakenD CLI and the AsyncAPI tools preinstalled; the checkout is plain `git` against Gitea. Only building that image the first time needs the internet. The runner runs up to four jobs side by side (`runner-config.yaml`), so a PR's two workflows run in parallel; within one workflow the gates still run in order.

**Backstage** rescans Gitea every 10 s (`app-config.yaml`, a demo setting). `demo refresh-catalog` forces an immediate rescan.

**If CI fails before any step ran** (`connection reset…`): **Re-run** the job, or `git commit --allow-empty -m retry && git push`.
