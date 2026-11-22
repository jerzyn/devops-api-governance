# DevOps-Driven API Governance — demo

The demo behind the talk *"DevOps-Driven API Governance"*: API governance built into the delivery loop, running entirely on your laptop.

Two APIs go through pull requests in one local Git server, and every PR passes the same five gates: the **Orders API**, a REST API described with OpenAPI, and the **Order Events API**, an event API described with AsyncAPI, on MQTT and on Kafka. One catalog, one governance repo, one set of guidelines; the tools change with the protocol, the gates don't.

- **Gitea** + **Gitea Actions** (`act_runner`) — local Git server, pull requests and CI.
- **Backstage** — API catalog that discovers the contract from Gitea, with the API guidelines as TechDocs.
- **OpenLint** — the API guidelines as code: lints every contract change.
- **Microcks** — a live mock from the contract, and a contract test of the running backend.
- **KrakenD** — API gateway whose config is generated from the contract and deployed by CI.
- **oasdiff** — blocks backward-incompatible contract changes.
- For events: **Mosquitto** and **Kafka** with a broker policy generated from the contract and the catalog, the **Microcks async minion** for event mocks and contract tests, and **Apicurio Registry** with `@asyncapi/diff` against breaking changes. See [Events](#events-asyncapi-on-mqtt-and-kafka).

Nothing here is a production setup: it simulates the control points around API delivery (source control, PRs, automated quality gates, contract testing, a discoverable catalog) so you can see and change them.

---

## Requirements

| | Docker | Podman |
|---|---|---|
| Engine | Docker Desktop, or Docker Engine with the Compose plugin (`docker compose version`) | Podman 4+ with [`podman-compose`](https://github.com/containers/podman-compose), rootless |
| OS | Linux, macOS (Intel or Apple Silicon), Windows with WSL2 | Linux (on macOS/Windows, use Docker Desktop) |
| Extra setup | none | enable the Podman socket and point the demo at it (one line, see below) |

Both need:
- **Resources:** ~6 GB of RAM for the engine for REST, ~10 GB with the event profiles (Docker Desktop: *Settings → Resources*; the Backstage image build is the heaviest step), ~12 GB of free disk (the images are ~6.5 GB).
- **Internet on the first start**, to pull images and build the Backstage and CI images. After that the demo, including its CI, runs offline.
- **Free ports:** 3000, 2222 (Gitea), 7007 (Backstage), 8080 (Microcks), 8081 (backend), 8090 (KrakenD); with the event profiles also 1883 (MQTT) and 8280 (Apicurio Registry).
- `git`, `curl` and `bash` (for the optional `demo` helper).

> Tested end to end on Linux with Podman. The Docker instructions use the same compose file and scripts, but weren't run end to end.

## Start

```bash
git clone https://codeberg.org/pierogi/devops-api-governance.git
cd devops-api-governance
```

**Docker:**

```bash
docker compose --profile contract --profile catalog --profile gateway up -d                                    # REST
docker compose --profile contract --profile catalog --profile gateway --profile events --profile kafka up -d   # REST + events
```

| Profile | Adds |
|---------|------|
| `contract` | Microcks with the async minion, and the REST backend |
| `catalog` | Backstage |
| `gateway` | KrakenD, for the REST step 4 |
| `events` | Mosquitto, the broker policy deployer, the MQTT backend and subscriber, Apicurio Registry |
| `kafka` | Kafka with its backend and subscriber (with the deployer and the registry) |

**Podman:**

```bash
systemctl --user enable --now podman.socket                           # once
echo "DOCKER_SOCK=/run/user/$(id -u)/podman/podman.sock" > .env        # once
podman-compose --profile contract --profile catalog --profile gateway up -d   # add --profile events --profile kafka for events
```

The first start takes a while (images to pull, Backstage and the CI image to build; expect 10–20 minutes). Later starts take under a minute.

`up` also **seeds** everything: no `.env` values, scripts or manual Gitea setup are needed (Podman's `DOCKER_SOCK` aside). One-shot services do the first-run work:

- **gitea-seed** creates the admin user (`demo` / `demo12345`), the `governance-demo` organization and its repos: the REST consumer repo `devops-api-governance` (from [`example/`](example/)), the event consumer repos `order-events-api` (MQTT, from [`example-mqtt/`](example-mqtt/)) and `order-events-kafka-api` (from [`example-kafka/`](example-kafka/)), and the governance repo `api-governance` that all three link (rulesets, guidelines, gate scripts). It also writes the CI runner's registration token.
- **microcks-seed** imports the REST and the MQTT contracts into Microcks (`microcks-seed-kafka`: the Kafka one).
- **broker-policy-seed**, **broker-policy-seed-kafka** and **registry-seed** (event profiles) apply the broker policy of the contracts on `main` and register their payload schemas.
- **ci-image** builds the image CI jobs run in, with OpenLint, oasdiff, the KrakenD CLI and the AsyncAPI tools preinstalled.

### Check that it runs

| Service | URL | Notes |
|---------|-----|-------|
| Gitea | http://localhost:3000 | sign in as `demo` / `demo12345` |
| Backstage | http://localhost:7007 | API catalog (guest sign-in) |
| API guidelines | http://localhost:7007/docs/default/component/api-guidelines | the rules as TechDocs in Backstage; every OpenLint error links here |
| Microcks | http://localhost:8080 | mocks and contract test results |
| Orders API mock | http://localhost:8080/rest/Orders+API/1.0.0/orders/123 | served from the contract's examples |
| backend | http://localhost:8081/orders/123 | the implementation under test |
| KrakenD | http://localhost:8090/orders/123 | the gateway; its routes come from the config CI deployed last |

Or, with the `demo` helper (below): `demo preflight` checks everything and ends with `READY` or a list of problems.

## Try it

After `up`, the consumer repo in Gitea has the full pipeline: all four gates. Clone it **outside this project and under another name** (it is also called `devops-api-governance`, so a default clone next to or inside this folder collides with it):

```bash
mkdir -p ~/demo && cd ~/demo
git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git orders-api
cd orders-api
```

Then branch, change `contracts/orders-openapi.yaml`, push, and open a pull request in Gitea. The five topics of the talk:

**1 — API Catalog.** One `catalog-info.yaml` makes an API visible to the whole organization. Backstage → **APIs** shows `orders-api`, discovered from Gitea; its **Definition** tab shows the contract.

**2 — Guidelines as code.** The guidelines live in the catalog (Backstage → **Docs** → `api-guidelines`) and run as OpenLint checks in CI. Break a rule (e.g. server URL `http://` instead of `https://`) and open a PR: `openlint-openapi-check` goes **red**, with rule, file, line and a link to the rule in the catalog. Fix it, push again: **green**.

**3 — Mocking & contract testing.** The contract is a live mock at once (`curl http://localhost:8080/rest/Orders+API/1.0.0/orders/123`). Make the contract promise a field the backend doesn't return (e.g. a required `currency`): `contract-test` goes **red**. Keep the contract in line with the code: **green**.

**4 — API gateway.** The contract isn't only tested, it is deployed: `gateway-deploy-check` generates a KrakenD config from the PR's contract, validates it, deploys it to the running gateway and re-runs the same contract test through the gateway (`:8090`).

**5 — Breaking changes.** A new *required* request parameter (e.g. a `channel` query parameter on `GET /orders/{orderId}`) breaks every client that doesn't send it. `breaking-changes-check` (oasdiff, `new-required-request-parameter`) blocks the PR: **red**, and the later gates are skipped. Make the parameter optional: **green**.

### Follow the talk step by step

In the talk the pipeline grows one gate at a time. The `demo` helper puts your Gitea in the state of any step and prepares the change for it, so you can replay the talk:

```bash
scripts/demo/demo install          # once: adds a `demo` command with tab completion to ~/.bashrc; open a new terminal
demo goto 1                        # Stage 1 start: contract only, no catalog entry, no gates
demo status                        # where you are and what comes next
demo shell                         # this terminal: cd into the demo clone (~/demo/orders-api), prompt with the branch
```

Each step is then: `git switch <branch>`, `git push -u origin <branch>`, open the PR in Gitea, merge. After a merge, `demo next` prepares the next step. [`presentation/cue-card.md`](presentation/cue-card.md) lists every step on one page. `demo goto <1|2|2-red|3|3-red|4|5|5-red|end>` jumps to any step, and `demo help` lists the rest.

`demo goto` force-pushes the consumer repo's `main` in *your local* Gitea and closes its open PRs. It never touches this project or GitHub.

### The talk in slide order: REST, then the same gate for events

The talk plays the five REST recordings above. After each REST step, a "same gate" slide shows that gate on event APIs, without a recording. To show an event step live as well, put its repo in the matching state. REST and event repos are separate, so `demo goto` and `demo events goto` don't disturb each other:

| Talk step | REST recording (`demo goto`) | "Same gate" slide | Live on events (`demo events goto`) |
|-----------|------------------------------|-------------------|-------------------------------------|
| 1. Catalog | `1` | Every interface goes in the catalog | `1`: the Order Events API appears with its broker, producer and consumer |
| 2. Guidelines | `2`, `2-red` (`http://` server URL) | One linter, two rulesets | `2`, `2-red` (`paid_at` breaks the camelCase rule) |
| 3. Mocks and contract tests | `3`, `3-red` (required `currency`) | The promise is tested where it is kept | `3`, `3-red` (required `currency` the backend never sends) |
| 4. Gateway | `4` (KrakenD 404, then 200) | Access is generated from the contract | `4`, then `demo events deny`: the broker refuses what the policy doesn't grant |
| 5. Breaking changes | `5`, `5-red` (required `channel`) | Breaking depends on who reads | `5`, `5-red` (removing `isPaid` fails FORWARD), then `kafka` for the same gates on Kafka |
| Close | `end` | Any protocol, same gates | `end` |

Two terminals make it easy: `demo shell` for `~/demo/orders-api`, and `demo events shell` for `~/demo/order-events-api` (`DEMO_SHELL_REPO=kafka demo events shell` for the Kafka repo). Before the talk, both `demo preflight` and `demo events preflight` must say `READY`. The one-page steps are [`presentation/cue-card.md`](presentation/cue-card.md) for REST and [`presentation/events/cue-card.md`](presentation/events/cue-card.md) for events.

The slides simplify a few things that the demo does in more detail:

- **Topics.** The slides use one topic, `orders.order-events.v1`. The demo has one topic per event type (`orders/v1/{orderId}/created` on MQTT, `orders.order-created.v1` and `orders.order-paid.v1` on Kafka), as the Kafka ruleset requires.
- **Broker ACLs.** The step 4 slide shows Strimzi `KafkaUser` resources. The demo runs plain Kafka, so the generated policy is applied as Kafka ACLs, and as dynamic-security roles on Mosquitto.
- **MCP.** The step 1 slide also puts MCP servers in the catalog. That part is on the slide only, and the demo has no MCP server.

---

## Events: AsyncAPI on MQTT and Kafka

With the `events` and `kafka` profiles, the same Gitea, CI runner, Microcks and Backstage also govern the Order Events API: an AsyncAPI 3.1 contract for order events, published on **MQTT** (Mosquitto) and on **Kafka**. Both event repos run the same five gates as the REST one:

| Gate | REST ([`example/`](example/)) | Events ([`example-mqtt/`](example-mqtt/), [`example-kafka/`](example-kafka/)) |
|------|--------------------|--------------------------------------|
| 1. Catalog | Backstage, `type: openapi` | Backstage, `type: asyncapi`; the broker is a Resource, producers and consumers are edges |
| 2. Guidelines | OpenLint, `openlint-ruleset.yaml` | `asyncapi validate` + OpenLint, `asyncapi-ruleset.yaml` plus the MQTT or Kafka rules |
| 3. Contract test | Microcks over HTTP | Microcks listens on the broker and checks every event against the schema |
| 4. Deploy | KrakenD config generated from the contract | broker policy generated from the contract and the catalog: Mosquitto roles, or Kafka topics and ACLs |
| 5. Breaking changes | oasdiff | `@asyncapi/diff` on the structure + Apicurio Registry compatibility on the payloads |

Backstage lists the REST and the event APIs side by side, and the API guidelines in TechDocs hold the general, REST, async, MQTT and Kafka rules in one document; every lint finding, REST or events, links to its section.

```bash
mkdir -p ~/demo && cd ~/demo
git clone http://demo:demo12345@localhost:3000/governance-demo/order-events-api.git          # MQTT
git clone http://demo:demo12345@localhost:3000/governance-demo/order-events-kafka-api.git    # Kafka
```

The `demo` helper replays the event steps too, with the same commands after `events`: `demo events goto 1`, `demo events next`, `demo events preflight`, `demo events deny` (the broker refusing what the policy does not grant), `demo events shell`. `demo fresh` resets REST and events together.

The whole event side, gate by gate, with its troubleshooting: [`docs/events.md`](docs/events.md). Its recorded demo: [`presentation/events/`](presentation/events/README.md).

---

## How it works

### Governance and consumer repositories

A product team's repo stays separate from the platform that governs it:

- **Governance** — [`governance/`](governance/): the policy (`openlint/`: the OpenAPI and AsyncAPI rulesets, custom functions, examples; `api-guidelines/`: the guidelines and their TechDocs wiring; `gateway/`: the OpenAPI→KrakenD generator; `contract-test/`, `breaking-changes/`, `broker-policy/`: the event gates) and the catalog app (`api-catalog/`). Single source of truth for the rules, published as one Gitea repo, `api-governance` ([`scripts/governance-bundle.sh`](scripts/governance-bundle.sh) picks the files).
- **Consumers** — [`example/`](example/) (REST), [`example-mqtt/`](example-mqtt/) and [`example-kafka/`](example-kafka/) (events): each product unit (contract, `catalog-info.yaml`, backend) with a thin PR workflow. They are **starting templates**: `gitea-seed` pushes them into fresh Gitea repos on each `up`, and **PRs happen against those Gitea repos**, never against this project.

The consumers' CI **links** the governance repo (clones it at run time) instead of copying the rules. Details: [`docs/demo-isolation.md`](docs/demo-isolation.md).

### The PR gates (REST)

The event repos' gates are described in [`docs/events.md`](docs/events.md). `example/.gitea/workflows/pr-governance.yml` runs four gates **in order**, each gated by `needs:`, so a failure stops the rest:

1. **`openlint-openapi-check`** — clones the governance repo for the ruleset and lints the OpenAPI files changed in the PR. **Fails on error-severity findings.** Each finding links to its rule in the API guidelines in Backstage.
2. **`breaking-changes-check`** — [`oasdiff`](https://github.com/oasdiff/oasdiff) (v1.19.0) diffs every PR-modified `*openapi*.{yml,yaml}` against the PR's base branch. **Fails on any ERR-severity breaking finding** (`--fail-on ERR`). New files (no baseline) and identical-content edits are skipped; the job is skipped on `workflow_dispatch`.
3. **`contract-test`** — imports the PR's contract into Microcks (which also updates the live mock) and tests the running `backend` against it. **Fails on drift.**
4. **`gateway-deploy-check`** — generates a KrakenD config from the PR's contract, validates it (`krakend check`), deploys it to the running gateway and re-runs the Microcks test through the gateway. **Fails on an invalid config or a gateway-level contract mismatch.**

On merge, Backstage's Gitea provider picks up `catalog-info.yaml` from `main` (it rescans every 10 s, a demo setting). A walkthrough of green and red for each gate: [`docs/ci-test-path.md`](docs/ci-test-path.md); scripted scenarios: [`tests/pr-governance.feature.md`](tests/pr-governance.feature.md).

CI jobs run in `localhost/devops-api-governance-ci:latest` ([`ci-image/Dockerfile`](ci-image/Dockerfile), amd64 or arm64) and check out with plain `git` from Gitea, so they download nothing. On a plain `node:22` runner (OpenLint needs Node 22+) the workflow installs the tools itself.

### Governance rules (OpenLint)

The ruleset extends OpenLint's built-in OpenAPI rules (the legacy `spectral:oas` set) with checks based on the API guidelines ([`governance/api-guidelines/docs/index.md`](governance/api-guidelines/docs/index.md)), for example:

- OpenAPI 3.x.y (3.1.y recommended); `info.title` in Title Case ending with `API`; semver `info.version`.
- camelCase JSON properties, PascalCase schema names, plural array names.
- kebab-case paths without a trailing `/`; URI template variables per RFC 6570.
- HTTPS server URLs; errors as `application/problem+json` with `type`, `title`, `detail`.

Severities: `error` (fails the gate) · `warn` (recommended) · `info` (optional). Run it locally:

```bash
npx -y openlint lint -r governance/openlint/openlint-ruleset.yaml governance/openlint/examples/openapi-valid.yaml    # passes
npx -y openlint lint -r governance/openlint/openlint-ruleset.yaml governance/openlint/examples/openapi-invalid.yaml  # violations
```

`openapi-invalid.yaml` breaks rules on purpose. The CI gate only lints files changed in the PR, so it doesn't affect other PRs.

### Backwards compatibility (oasdiff)

Typical changes the gate blocks: a new required request parameter; a narrowed request parameter (pattern added, `minLength` raised, …); a response property removed; an operation removed.

| Case | Behaviour |
|------|-----------|
| PR adds a brand-new `*openapi*.yaml` (no baseline on `main`) | skipped (`--diff-filter=M`); the job passes |
| PR touches an OpenAPI file but the content is identical | skipped (`git diff --quiet`), with a `::notice::` |
| PR changes no OpenAPI file | the oasdiff step doesn't run |
| `workflow_dispatch` | the whole job is skipped |

The gate is strict: only a backward-compatible change (optional parameter, default value, dropping the new constraint, …) clears it. Bumping `info.version` to a new major alone doesn't.

```bash
# Linux amd64 (other platforms: https://github.com/oasdiff/oasdiff/releases)
curl -fsSL -o /tmp/oasdiff.tgz https://github.com/oasdiff/oasdiff/releases/download/v1.19.0/oasdiff_1.19.0_linux_amd64.tar.gz
tar -xzf /tmp/oasdiff.tgz -C /tmp && sudo install -m 0755 /tmp/oasdiff /usr/local/bin/oasdiff
oasdiff breaking --fail-on ERR origin/main:contracts/orders-openapi.yaml contracts/orders-openapi.yaml -f githubactions
```

### Contract testing (Microcks)

`backend` implements the Orders API contract. It can also serve contract-violating responses:

```bash
BACKEND_DRIFT=true  docker compose --profile contract up -d backend    # contract test fails (red)
BACKEND_DRIFT=false docker compose --profile contract up -d backend    # back to green
```

With Podman, `backend` can't be recreated while `krakend` (which depends on it) runs; the talk's walkthrough changes the contract instead. Microcks runs as the all-in-one "uber" image with in-memory storage: imported contracts and test results are gone after a restart and re-imported by CI.

### Backstage catalog

The Backstage app is committed under `governance/api-catalog/` and built in the container (no Node on the host). It serves on port 7007 and reads Gitea with the seeded admin. The Gitea provider scans the `governance-demo` organization for `catalog-info.yaml` and shows the API with its OpenAPI definition and a link to Microcks. The governance repo's `api-guidelines` component carries the guidelines as TechDocs (**Docs** → `api-guidelines`).

The official `@microcks/microcks-backstage-provider` (0.0.7) isn't used: it depends on removed Backstage packages and crashes current Backstage. Microcks is linked from the API entity instead.

### Repository layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | All services, the seed services and the profiles (`contract`, `catalog`, `gateway`, `events`, `kafka`). |
| `example/` | The REST consumer repo template: `contracts/orders-openapi.yaml`, `catalog-info.yaml`, `backend/`, `.gitea/workflows/pr-governance.yml`. |
| `example-mqtt/`, `example-kafka/` | The event consumer repo templates: AsyncAPI contract, `catalog-info.yaml`, `backend/`, `subscriber/`, PR and publish workflows. |
| `governance/` | `openlint/`, `api-guidelines/`, `gateway/` (generator + `deployer/` sidecar that deploys configs to KrakenD), `contract-test/`, `breaking-changes/`, `broker-policy/` (generator + `deployer/` that applies it to the brokers), `api-catalog/` (Backstage). |
| `mosquitto/` | The MQTT broker's config, demo accounts and policy bootstrap. |
| `ci-image/` | The CI job image. |
| `runner-config.yaml` | Puts CI job containers on `gitea-network` and in the CI image. |
| `scripts/` | Seed scripts and the governance bundle; `scripts/demo/` is the `demo` helper (`scripts/demo/events/`: its event steps). |
| `presentation/` | The talk as a PDF (demo clips embedded) and the demo's screenplay ([`presentation/README.md`](presentation/README.md)); `presentation/events/`: the event demo's screenplay and the broker policy animation. |
| `docs/`, `tests/` | Design notes, the event guide ([`docs/events.md`](docs/events.md)) and scripted PR scenarios (REST and events). |
| `gitea-data/`, `runner-data/` | Local runtime state, git-ignored, disposable. |

---

## Troubleshooting

**Both engines**
- **A port is already in use:** another service (or another copy of this stack) uses 3000, 2222, 7007, 8080, 8081, 8090, 1883 or 8280. Stop it, then `up` again.
- **Changes you made in Gitea's `main` disappeared:** every `up` runs `gitea-seed`, which force-pushes `example/` over the consumer repo's `main`. If you use `demo`, run `demo goto <step>` after `up`.
- **Backstage doesn't list the API yet:** wait ~10 s after the merge and reload; `demo refresh-catalog` forces a rescan.
- **A CI job fails before any step ran:** the runner couldn't start the job container. Check `docker logs gitea-runner` / `podman logs gitea-runner`, then use **Re-run** on the run page.

**Docker**
- **Docker Desktop:** give it ~6 GB of memory; the Backstage build can fail with less.
- **Apple Silicon:** all images are available for arm64, and the CI image installs arm64 tools.

**Podman**
- **`gitea-seed` fails or the runner never registers:** the socket isn't reachable. Check `systemctl --user status podman.socket` and that `.env` holds your user id (`id -u`) in `DOCKER_SOCK`.
- **Restarting `backstage` or `gitea-runner` wipes your Gitea `main`:** Podman starts their dependency `gitea-seed` again (Docker doesn't). With `demo`, run `demo goto <step>` afterwards.
- **`backend` can't be recreated** while `krakend` runs ("has dependent containers").

## Stop / reset

```bash
P="--profile contract --profile catalog --profile gateway --profile events --profile kafka"
docker compose $P down       # stop
docker compose $P down -v    # + drop the seeded volumes
rm -rf gitea-data runner-data   # + drop Gitea and runner state
```

With Podman, use `podman-compose` with the same arguments, and `podman unshare rm -rf gitea-data runner-data` (the files belong to container users). `demo fresh` does the full wipe and restart in one go.

## Security note

This is a local demo. `gitea-seed`, `gitea-runner` and `krakend-deployer` get access to the container engine socket (to run the Gitea CLI, start CI jobs and restart KrakenD); the `/deploy` endpoints of `krakend-deployer` and `broker-policy-deployer` are unauthenticated on the compose network; the brokers speak plain MQTT and Kafka, and the demo accounts and their passwords sit in `mosquitto/users.txt`, the compose file and the workflows. Fine on a laptop, not a pattern for shared infrastructure.

## For presenters

The talk PDF, with the recorded demo embedded, and the demo's step-by-step script are in [`presentation/`](presentation/README.md).

## Using an AI coding agent

Starter prompt for Claude Code or a similar agent:

> Get familiar with the repo, prepare the environment, and run the tests in `tests/pr-governance.feature.md` and `tests/events-governance.feature.md`. Present a summary as a table with links so I can verify the intermediate states.

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Share and adapt with attribution — see [LICENSE](LICENSE).
