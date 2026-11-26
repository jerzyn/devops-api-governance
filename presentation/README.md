# For presenters

The talk *"DevOps-Driven API Governance"* and the script of the demo it plays back. To install and start the stack, see the [main README](../README.md).

## What is here

| File | What it is |
|------|------------|
| [`DevOps-Driven API Governance — FOST London 2026.pdf`](DevOps-Driven%20API%20Governance%20%E2%80%94%20FOST%20London%202026.pdf) | The talk (FOST London, 1 October 2026) as a PDF, with the five demo clips embedded. Click a demo slide to play it in Okular or Adobe Acrobat; other viewers show a still. |
| [`cue-card.md`](cue-card.md) | Every step on one page, for the REST and the event API together: commands, clicks, one line to say. |
| [`screenplay.md`](screenplay.md) | The full script of the demo, for the REST and the event API together: narrative, what is on screen in each step, terminal and browser steps, the expected log lines, retakes. |
| [`events/`](events/README.md) | The event half of each step and the broker policy animation. |

## The demo

The CI pipeline grows one gate at a time, and every step is **one PR in the orders repo for both APIs**, the Orders API (REST) and the Order Events API (MQTT):

1. **Catalog**: merge one `catalog-info.yaml`; both APIs appear in Backstage at once.
2. **Guidelines**: the lint gates catch an `http://` server URL and a snake_case `paid_at`; each error links to its rule in the catalog.
3. **Mocks & contract testing**: the contracts are live mocks; the contract tests catch a `currency` the backends don't send.
4. **Deploy from the contract**: the KrakenD config and the broker policy are generated from the contracts; `curl` through KrakenD goes from 404 to 200, and `demo deny` shows the broker refusing what the contract doesn't grant.
5. **Breaking changes**: oasdiff blocks a new required parameter, the schema registry blocks a removed `isPaid`; the later gates are skipped.

After step 5, the same gates run on the Kafka repo (`demo goto kafka`).

## The `demo` command

Install once with `scripts/demo/demo install` (adds one line to `~/.bashrc`, then open a new terminal). It works from any directory, completes with Tab, and works with Docker and Podman (it picks the engine that runs the stack; `DEMO_ENGINE=docker|podman` forces one).

| Command | When |
|---------|------|
| `demo fresh` | Start over: wipes the demo Gitea (all PRs and CI runs) so PR numbers start at #1, and sets up Stage 1. Asks first. |
| `demo goto <1\|2\|2-red\|3\|3-red\|4\|5\|5-red\|kafka\|end>` | Puts Gitea, Backstage, the gateway, the Microcks mocks, the schema registry and the broker policy in the state right before that step, and prepares the step's branch in `~/demo/orders-api` (Kafka steps: `~/demo/order-events-kafka-api`). Waits for any CI still running from an aborted run. |
| `demo preflight` | Checks everything and ends with `READY` or a list of problems with the fix for each. |
| `demo shell` | `cd` into the demo clone, short prompt with the branch (`DEMO_SHELL_REPO=kafka` for the Kafka clone). |
| `demo deny` | The broker refusing what the policy does not grant, on MQTT and Kafka. |
| `demo next` | Between steps, after each merge: prepares the next step's branch (says so if you are too early). |
| `demo status` | Where the demo is and what comes next. |

The scripts behind it are in [`../scripts/demo/`](../scripts/demo/).

## Running the demo, in short

1. Stack up (main README), then `demo fresh`, or `demo goto 1`.
2. Sign in to Gitea in the browser (`demo` / `demo12345`); open the tabs the cue card lists.
3. One terminal: `demo shell`. A second terminal: `demo preflight` must say `READY`.
4. Run each stage following [`cue-card.md`](cue-card.md): switch to the branch, show the change, push, open the PR, show the gate's verdict, merge. Between steps: `demo next`.
5. If a step goes wrong: `demo goto <step>`, `demo shell` again, and repeat it.

The demo was run end to end on Linux with Podman.
