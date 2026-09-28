# For presenters

The talk *"DevOps-Driven API Governance"* and the script of the demo it plays back. To install and start the stack, see the [main README](../README.md).

## What is here

| File | What it is |
|------|------------|
| [`DevOps-Driven API Governance — FOST London 2026.pdf`](DevOps-Driven%20API%20Governance%20%E2%80%94%20FOST%20London%202026.pdf) | The talk (FOST London, 1 October 2026) as a PDF, with the five demo clips embedded. Click a demo slide to play it in Okular or Adobe Acrobat; other viewers show a still. |
| [`screenplay.md`](screenplay.md) | The full script of the five demo stages: narrative, what is on screen at the start of each stage, terminal and browser steps, expected results, measured timings, retakes. |
| [`cue-card.md`](cue-card.md) | The same steps on one page. |

## The demo

The talk plays back five recordings in which the CI pipeline grows one gate at a time:

1. **Catalog**: merge a `catalog-info.yaml`; the API appears in Backstage.
2. **Spectral**: the gate catches an `http://` server URL; the error links to the rule in the catalog.
3. **Mocks & contract testing**: the contract is a live mock; the contract test catches a field the backend doesn't return.
4. **API gateway**: the gateway config is generated from the contract; `curl` through KrakenD goes from 404 to 200.
5. **Backwards compatibility**: oasdiff blocks a new required parameter; the later gates are skipped.

## The `demo` command

Install once with `scripts/demo/demo install` (adds one line to `~/.bashrc`, then open a new terminal). It works from any directory, completes with Tab, and works with Docker and Podman (it picks the engine that runs the stack; `DEMO_ENGINE=docker|podman` forces one).

| Command | When |
|---------|------|
| `demo fresh` | Start over: wipes the demo Gitea (all PRs and CI runs) so PR numbers start at #1, and sets up Stage 1. Asks first. |
| `demo goto <1\|2\|2-red\|3\|3-red\|4\|5\|5-red\|end>` | Puts Gitea, Backstage, the gateway and the Microcks mock in the state right before that step, and prepares the step's branch in `~/demo/orders-api`. Waits for any CI still running from an aborted run. |
| `demo preflight` | Checks everything and ends with `READY` or a list of problems with the fix for each. |
| `demo shell` | `cd` into the demo clone, short prompt with the branch. |
| `demo next` | Between steps, after each merge: prepares the next step's branch (says so if you are too early). |
| `demo status` | Where the demo is and what comes next. |

The scripts behind it are in [`../scripts/demo/`](../scripts/demo/).

## Running the demo, in short

1. Stack up (main README), then `demo fresh`, or `demo goto 1`.
2. Sign in to Gitea in the browser (`demo` / `demo12345`); open the tabs the screenplay lists for Stage 1.
3. One terminal: `demo shell`. A second terminal: `demo preflight` must say `READY`.
4. Run each stage following [`cue-card.md`](cue-card.md): switch to the branch, show the change, push, open the PR, show the gate's verdict, merge. Between steps: `demo next`.
5. If a step goes wrong: `demo goto <step>`, `demo shell` again, and repeat it.

The demo was run end to end on Linux with Podman.
