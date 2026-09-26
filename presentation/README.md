# For presenters

Material for giving the talk *"DevOps-Driven API Governance"* and for recording the demo it plays back. To install and start the stack, see the [main README](../README.md).

## What is here

| File | What it is |
|------|------------|
| `DevOps Driven Governance - London 2026.pdf` / `.txt` | The slide deck and its text transcript. |
| [`deck-changes.md`](deck-changes.md) | What to change in the deck, per PDF page, so it matches the recordings (the API gateway step, the breaking-change example). The deck itself is not edited in this repo. |
| [`screenplay.md`](screenplay.md) | The full script of the five recordings: narrative, what is on screen at the start of each stage, terminal and browser steps, expected results, measured timings, retakes, recording and editing notes. |
| [`cue-card.md`](cue-card.md) | The same steps on one page, to keep next to you while recording. |

## The recordings

The talk plays back five recordings in which the CI pipeline grows one gate at a time:

1. **Catalog**: merge a `catalog-info.yaml`; the API appears in Backstage.
2. **Spectral**: the gate catches an `http://` server URL; the error links to the rule in the catalog.
3. **Mocks & contract testing**: the contract is a live mock; the contract test catches a field the backend doesn't return.
4. **API gateway**: the gateway config is generated from the contract; `curl` through KrakenD goes from 404 to 200.
5. **Backwards compatibility**: oasdiff blocks a new required parameter; the later gates are skipped.

## Tools: the `demo` command

Install once with `scripts/demo/demo install` (adds one line to `~/.bashrc`, then open a new terminal). It works from any directory, completes with Tab, and works with Docker and Podman (it picks the engine that runs the stack; `DEMO_ENGINE=docker|podman` forces one).

| Command | When |
|---------|------|
| `demo fresh` | Before the final take: wipes the demo Gitea (all PRs and CI runs from rehearsals) so PR numbers start at #1, and sets up Stage 1. Asks first. |
| `demo goto <1\|2\|2-red\|3\|3-red\|4\|5\|5-red\|end>` | Before a take or a retake: puts Gitea, Backstage, the gateway and the Microcks mock in the state right before that step, and prepares the step's branch in `~/demo/orders-api`. Waits for any CI still running from an aborted take. |
| `demo preflight` | Before pressing record: checks everything and ends with `READY: record …` or a list of problems with the fix for each. |
| `demo shell` | In the recording terminal: `cd` into the demo clone, short prompt with the branch. |
| `demo next` | Between steps, after each merge: prepares the next step's branch (says so if you are too early). |
| `demo status` | Where the demo is and what comes next. |
| `demo rehearse` | Before the recording day: runs the whole screenplay against the stack (~9 min) and prints PASS/FAIL per check. Leaves the demo at `end`; run `demo goto 1` afterwards. |
| `demo cards <dir>` | Title cards for the five stages (3 s, 1920×1080). |
| `demo trim`, `demo speed`, `demo concat` | Editing: cut a range, speed up CI waiting, join cards and clips. |

The scripts behind it are in [`../scripts/demo/`](../scripts/demo/).

## Recording, in short

1. Stack up (main README), then `demo fresh` for the final take, or `demo goto 1` for a dry run.
2. Sign in to Gitea in the browser (`demo` / `demo12345`); open the tabs the screenplay lists for Stage 1.
3. Recording terminal: `demo shell`. Second, off-camera terminal: `demo preflight` must say `READY`.
4. Record each stage following [`cue-card.md`](cue-card.md): switch to the branch, show the change, push, open the PR, show the gate's verdict, merge. Between steps: `demo next`.
5. If a take goes wrong: `demo goto <step>`, `demo shell` again, record again.
6. Edit: title cards, cut the CI waits, keep Stage 5's final green run at full speed. See "Post-production" in the screenplay.

The recordings were rehearsed end to end on Linux with Podman (`demo rehearse`).
