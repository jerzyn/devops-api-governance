# For presenters

The script of the demo the talk plays back. To install and start the stack, see the [main README](../README.md).

## What is here

| File | What it is |
|------|------------|
| [`screenplay.md`](screenplay.md) | The full script: what each stage shows, the terminal and browser steps, the expected log lines, CI durations, retakes. |
| [`cue-card.md`](cue-card.md) | The same steps on one page, for recording. |
| [`acl-animation.html`](acl-animation.html) | The broker policy, animated for the slides: what the contract allows passes the broker, the rest is denied. Open it in a browser; Space or → steps, `A` autoplays, `K` switches between MQTT and Kafka (`?protocol=kafka&autoplay` in the URL does the same). Works offline. |

## The demo

The PR workflow grows one gate at a time on the MQTT repo, then the same gates run on Kafka:

1. **Catalog**: merge a `catalog-info.yaml`; the API appears in Backstage with its producer and consumer.
2. **Lint**: `paid_at` breaks the property naming rule; the error links to the guideline in Backstage.
3. **Contract test**: Microcks listens on the broker and catches a required field the backend never sends.
4. **Broker policy**: the policy is generated from the contract and the catalog; `demo-async deny` shows the broker refusing the rest.
5. **Breaking changes**: removing `isPaid` fails the registry's FORWARD check; deprecating it passes.
6. **Kafka**: an optional field passes all four gates; removing `isPaid` is red there too.

## The `demo` command

Install once with `scripts/demo/demo install` (adds one line to `~/.bashrc`; open a new terminal). It works from any directory, completes with Tab, and works with Docker and Podman (`DEMO_ENGINE=docker|podman` forces one).

| Command | When |
|---------|------|
| `demo-async fresh` | Final take: wipes the demo Gitea so PR numbers start at #1, then sets up Stage 1. Asks first. |
| `demo-async goto <1\|2\|2-red\|3\|3-red\|4\|5\|5-red\|kafka\|end>` | Puts both Gitea repos, Backstage, Microcks, the registry and the broker policy right before that step, and prepares its branch. |
| `demo-async preflight` | Checks everything; ends with `READY` or the problems and their fixes. |
| `demo-async shell` | `cd` into the demo clone (`DEMO_SHELL_REPO=kafka` for the Kafka one), short prompt with the branch. |
| `demo-async next` / `demo-async status` | After each merge: prepare the next branch / where the demo is. |
| `demo-async deny` | The broker refusing what the policy does not grant. |

## Running the demo, in short

1. Stack up with `--profile contract --profile catalog --profile kafka`, then `demo-async fresh` (or `demo-async goto 1`).
2. Sign in to Gitea (`demo` / `demo12345`) and Backstage (guest).
3. Terminal 1: `demo-async shell`. Terminal 2: `demo-async preflight` → `READY`.
4. Follow [`cue-card.md`](cue-card.md); `demo-async next` after each merge.
5. If a take goes wrong: `demo-async goto <step>`, `demo-async shell`, repeat.
