# Screenplay: async API governance, built up gate by gate

> **Note.** This screenplay was written for the recordings of the event demo on its own, in a repo of its own. The event API now lives in the orders repo next to the REST API, and every step is one PR for both: [`../cue-card.md`](../cue-card.md) has the current steps and commands (`demo …`, no longer `demo events …`). The event half of each step below still applies.

Short recordings, one per pipeline stage, played back during the talk. Each stage adds one gate to the PR workflow of the **Order Events API** (MQTT) and shows it working. A last recording shows the same gates on the **Kafka** version of the API.

Every recording has two parts:
- **Terminal:** git commands in the demo clone of the Gitea repo.
- **Browser:** Gitea (PR, changed files, CI logs), Backstage, Microcks, Apicurio.

Between steps there is one off-camera command, always the same: `demo events next`. **While recording, use [`cue-card.md`](cue-card.md)**: the same steps on one page.

Every step below was run end to end against the stack, with real PRs and real CI: every red, every fix, every merge, and `demo events next` after each one. CI durations are from that run.

## Run of show

| Stage | Adds | Key shot (what the audience should remember) |
|---|---|---|
| 1 | Catalog | Merge a `catalog-info.yaml`, and the Order Events API appears in Backstage, rendered as AsyncAPI docs, with who produces and who consumes it. No CI yet. |
| 2 | Lint | Red check with one finding, `api-peak:async11:2026-property-naming`, whose link opens the guideline in Backstage. Renaming `paid_at` to `paidAt` turns it green. |
| 3 | Contract test (Microcks) | Microcks listens on the broker: `required property 'currency' not found` in all 5 messages the backend sent. The backend that sends `currency` (deployed by the gate) turns it green. |
| 4 | Broker policy | The policy is generated from the contract and the catalog and applied to Mosquitto. Then `demo events deny`: the broker refuses a topic the contract does not have. The ACL animation in the slides follows. |
| 5 | Breaking changes (diff + Apicurio) | Removing `isPaid`: the registry says the new schema is not FORWARD-compatible, and the later gates are skipped. Deprecating it instead turns everything green. |
| 6 | Kafka | The same four gates on the Kafka repo: an optional field passes, with topics and ACLs applied to Kafka; removing `isPaid` is red there too. |

## How every stage works

Stages 2, 3 and 5 have two parts. **Part 1** installs the new gate. **Part 2** is the real shot: the gate catches a bad change (red, one-line fix, green). Stages 1 and 4 have a single part; Stage 6 has a green PR and a red one.

1. **Prep (off camera):** `demo events next`. It reads Gitea `main`, works out the next step and creates its branch **in the demo clone**, committed but **not pushed**. It brings the clone's `main` up to Gitea `main` first and leaves what your terminal has checked out alone. After a `demo events goto`, the next branch is already there.
2. **Terminal, show and push:** `git switch <branch>`, show the change, `git push -u origin <branch>`.
   - Contract changes are a few lines: `git diff main -- contracts/`.
   - Workflow changes are long: `git diff --stat main` in the terminal, and the change itself in the PR's **Files changed** tab.
3. **Browser, PR and checks:** `compare/main...<branch>` → **New Pull Request** → **Create Pull Request**. Let the checks run, then open the one log line that matters (each stage names it).
4. **Terminal, fix (red demos only):** one `sed`, `git commit -am`, `git push`. The checks re-run on the same PR.
5. **Browser, merge:** **Create merge commit**. The next step starts from there.

Keep the same clone for the whole walk-through: `~/demo/order-events-api`, and `~/demo/order-events-kafka-api` for Stage 6. `next` adds each branch to it; `goto` replaces it with a fresh one. A `git push` does not open a PR in Gitea: PRs are opened in the browser.

---

## Before recording

1. **Stack up** with every profile:
   ```bash
   docker compose --profile contract --profile catalog --profile events --profile kafka up -d
   ```
2. **For the final recording only: `demo events fresh`.** It wipes the demo Gitea (PRs, CI runs, branches), brings the stack up again and runs `goto 1`, so PR numbers start at #1. It asks before deleting anything. For a dry run, `demo events goto 1` is enough.
3. `demo events goto 1` puts Gitea `main` of both repos at the start, closes open PRs, deletes `feat/*` branches, syncs the governance repo, re-applies the broker policy, resets the registry and the Microcks mocks to `main`, clears the catalog, prebuilds the guidelines page and makes fresh demo clones with the Stage 1 branch in them.
4. In the browser, **sign in to Gitea** at http://localhost:3000/user/login as `demo` / `demo12345`, and to Backstage (http://localhost:7007) as guest.
5. Recording terminal: `demo events shell` (`cd`s into the clone, short prompt with the branch, clears the screen).
6. Second terminal, not recorded: `demo events preflight` must end with `READY`.

## Screen layout

- Terminal on the left, browser on the right. Terminal font 18–20 pt, browser zoom 125–150%.
- Terminal 1 (recorded): in the demo clone. Terminal 2 (not recorded): `demo` commands only.
- Browser tabs per stage are listed below; close the others.

---

## Stage 1: catalog

**Say:** "The API is described by an AsyncAPI contract. First, we put it where people look for APIs."

**Tabs:** Gitea repo, Backstage → APIs (empty list of order APIs, the Kafka one aside).

1. `git switch feat/add-catalog-entry`, `git diff --stat main`, `git show --stat`. Then `cat catalog-info.yaml | head -40`: the API with `type: asyncapi`, `orders-backend` with `providesApis`, `orders-subscriber` with `consumesApis`, the broker as a Resource.
2. `git push -u origin feat/add-catalog-entry`, open the PR. No checks: there is no gate yet.
3. Merge. Backstage → APIs: **Order Events API** appears within seconds (the provider rescans every 10 s).
4. Open it: **Definition** renders channels, operations, messages and MQTT bindings. **Dependencies** / Catalog Graph: backend → API → subscriber, both on `mqtt-broker`.

## Stage 2: lint

**Part 1, the gate.** `git switch feat/add-lint-gate`, `git diff --stat main` (adds `.gitea/workflows/pr-governance.yml`), push, PR, show **Files changed**: the workflow clones the central governance repo and lints with the ruleset for the contract's protocol. Merge once green (about 5 s of CI).

**Part 2, the catch.**

**Say:** "The team adds when an order was paid."

1. `git switch feat/order-paid-at`, `git diff main -- contracts/`: a new optional property `paid_at`.
2. Push, open the PR. `asyncapi-lint` goes **red** in about 6 s. **Details**:
   ```
   error  api-peak:async11:2026-property-naming  Property 'paid_at' MUST be camelCase.
    http://localhost:7007/docs/default/component/api-guidelines/async/#property-naming-api-peakasync112026-property-naming
   ```
3. Click the link: the guideline opens in Backstage TechDocs.
4. Fix:
   ```bash
   vi +132 contracts/order-events-asyncapi.yaml
   ```
   Line 132: `        paid_at:` → `        paidAt:`
   ```bash
   git commit -am "Name it paidAt" && git push
   ```
   Green. Merge.

## Stage 3: contract test

**Part 1, the gate.** `git switch feat/add-contract-test-gate`, push, PR, **Files changed**: a `contract-test` job after lint. Green in about 20 s (Microcks listens on both topics). Merge.

**Part 2, the catch.**

**Say:** "Now the contract promises something the backend does not send."

1. `git switch feat/order-currency`, `git diff main -- contracts/`: `currency` added to `OrderCreated` and made **required**.
2. Push, open the PR. Lint passes; `contract-test` goes **red** in about 25 s:
   ```
   FAIL  SEND sendOrderCreated  on orders/v1/+/created  (5 messages, 5 invalid)
         required property 'currency' not found
         report: http://localhost:8080/#/tests/...
   PASS  SEND sendOrderPaid  on orders/v1/+/paid  (5 messages, 0 invalid)
   ```
3. Optional: open the report link in Microcks: each received message with its validation error.
4. Fix the backend, not the contract: it sends the currency the contract promises.
   ```bash
   vi +33 events-backend/server.js
   ```
   Line 33: `  return { orderId, createdAt: new Date().toISOString() };` → `  return { orderId, createdAt: new Date().toISOString(), currency: "PLN" };`
   ```bash
   git commit -am "Send the currency the contract promises" && git push
   ```
   `contract-test` first deploys the PR's `events-backend/` into `mqtt-backend` (step **Deploy the PR's backend**), then listens. Green. Merge.

## Stage 4: broker policy

**Say:** "A REST API has a gateway. An event API has a broker, and today anyone with a password can read anything."

1. `git switch feat/add-broker-policy-gate`, push, PR. **Files changed**: a `broker-policy` job after the contract test.
2. In the job log (about 35 s), show the **generated policy**: `orders-backend` may publish `orders/v1/+/created` and `orders/v1/+/paid`, `orders-subscriber` may subscribe to exactly those, Microcks may read them. Then `broker policy matches the contract and the catalog`, and the contract test passing again under the new policy.
3. Merge.
4. Terminal 1: `demo events deny`:
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
5. In the talk, the ACL animation follows ([`acl-animation.html`](acl-animation.html), Space to step).

## Stage 5: breaking changes

**Part 1, the gate.** `git switch feat/add-breaking-changes-gate`, push, PR (all four gates, about 40 s). **Files changed**: `breaking-changes` inserted between lint and the contract test, and `main-publish.yml`, which registers the schemas after each merge. Merge; the **Publish API (main)** run registers main's payload schemas in Apicurio (http://localhost:8280, group `order-events-api`).

**Part 2, the catch.**

**Say:** "Someone thinks `isPaid` is redundant now that we have `paidAt`."

1. `git switch feat/drop-is-paid`, `git diff main -- contracts/`: `isPaid` removed from `OrderPaid`.
2. Push, open the PR. Lint passes. `breaking-changes`, about 15 s in: the structural diff is clean (same topics, same operations), the registry check is **red**:
   ```
   FAIL  orders/v1/{orderId}/paid (OrderPaid): not FORWARD-compatible with the registered schema
         consumers built on the registered schema could not read what the API would now send
   ```
   `contract-test` and `broker-policy` are **skipped**.
3. Fix: keep the field, mark it deprecated:
   ```bash
   git checkout main -- contracts/order-events-asyncapi.yaml    # isPaid back
   vi +135 contracts/order-events-asyncapi.yaml
   ```
   After line 135 (`          type: boolean`, under `isPaid:`), add: `          deprecated: true`
   ```bash
   git commit -am "Deprecate isPaid instead of removing it" && git push
   ```
   All four gates green in about 45 s. Merge; **Publish API (main)** registers the new version.

## Stage 6: the same gates on Kafka

**Say:** "Same API, on Kafka. Same gates, same scripts; only the environment of the workflow differs."

**Terminal:** `DEMO_SHELL_REPO=kafka demo events shell` (into `~/demo/order-events-kafka-api`).

1. `git switch feat/kafka-paid-at`, `git diff main -- contracts/`: optional `paidAt`.
2. Push, PR. All four gates green. In the logs: lint picked `asyncapi-kafka-ruleset.yaml`; the contract test listened on `kafka://kafka:9094`; the broker policy created no new topic and reconciled the ACLs. Merge.
3. `demo events next` (prepares the red branch), `git switch feat/kafka-drop-is-paid`, push, PR: `breaking-changes` **red**, `orders.order-paid.v1 (OrderPaid): not FORWARD-compatible`. Do not merge: end of the demo.

---

## Retakes

`demo events goto <target>` puts everything at the start of a step: `1`, `2`, `2-red`, `3`, `3-red`, `4`, `5`, `5-red`, `kafka`, `end`. It waits for CI still running from an aborted take, closes open PRs, deletes `feat/*` branches, and replaces the demo clones; `cd` into the clone again (`demo events shell`). Then `demo events preflight`.

Never run `docker compose up` during a recording: `gitea-seed` force-pushes the template repos over Gitea `main`. If you did, `demo events goto <step>`.

## Appendix: what each state contains

| `goto` | Gitea main of `order-events-api` | Next branch |
|---|---|---|
| `1` | contract, backend, subscriber; no catalog entry, no workflow | `feat/add-catalog-entry` |
| `2` | + catalog entry | `feat/add-lint-gate` |
| `2-red` | + lint gate | `feat/order-paid-at` |
| `3` | + `paidAt` | `feat/add-contract-test-gate` |
| `3-red` | + contract-test gate | `feat/order-currency` |
| `4` | + required `currency`, the backend sends it | `feat/add-broker-policy-gate` |
| `5` | + broker-policy gate | `feat/add-breaking-changes-gate` |
| `5-red` | + breaking-changes gate, main-publish | `feat/drop-is-paid` |
| `kafka` | + `isPaid` deprecated (all MQTT steps merged) | `feat/kafka-paid-at` (Kafka repo) |
| `end` | Kafka repo: + `paidAt` | `feat/kafka-drop-is-paid` (Kafka repo) |
