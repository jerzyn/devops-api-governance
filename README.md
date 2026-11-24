# DevOps-Driven API Governance — demo

The demo behind the talk *"DevOps-Driven API Governance"*: API governance built into the delivery loop, running entirely on your laptop.

One repo holds two APIs side by side: the **Orders API**, a REST API described with OpenAPI, and the **Order Events API**, an event API on MQTT described with AsyncAPI. Every pull request in a local Git server passes the same five steps for both at once. A second repo runs the event API on **Kafka** with the same gates. One catalog, one governance repo, one set of guidelines; the tools change with the protocol, the gates don't.

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
docker compose --profile contract --profile catalog --profile gateway --profile events --profile kafka up -d
```

Every step of the demo governs the REST and the event API in one pull request, so it needs all five profiles. Without `kafka` everything but the Kafka repo works.

| Profile | Adds |
|---------|------|
| `contract` | Microcks with the async minion, and the REST backend |
| `catalog` | Backstage |
| `gateway` | KrakenD, for step 4 (REST) |
| `events` | Mosquitto, the broker policy deployer, the MQTT backend and subscriber, Apicurio Registry: the event half of every step |
| `kafka` | Kafka with its backend and subscriber (with the deployer and the registry) |

**Podman:**

```bash
systemctl --user enable --now podman.socket                           # once
echo "DOCKER_SOCK=/run/user/$(id -u)/podman/podman.sock" > .env        # once
podman-compose --profile contract --profile catalog --profile gateway --profile events --profile kafka up -d
```

The first start takes a while (images to pull, Backstage and the CI image to build; expect 10–20 minutes). Later starts take under a minute.

`up` also **seeds** everything: no `.env` values, scripts or manual Gitea setup are needed (Podman's `DOCKER_SOCK` aside). One-shot services do the first-run work:

- **gitea-seed** creates the admin user (`demo` / `demo12345`), the `governance-demo` organization and its repos: the orders repo `devops-api-governance` with the REST and the MQTT API (from [`example/`](example/)), the Kafka repo `order-events-kafka-api` (from [`example-kafka/`](example-kafka/)), and the governance repo `api-governance` that both link (rulesets, guidelines, gate scripts). It also writes the CI runner's registration token.
- **microcks-seed** imports the REST and the MQTT contracts into Microcks (`microcks-seed-kafka`: the Kafka one).
- **broker-policy-seed**, **broker-policy-seed-kafka** and **registry-seed** (event profiles) apply the broker policy of the contracts on `main` and register their payload schemas.
- **ci-image** builds the image CI jobs run in, with OpenLint, oasdiff, the KrakenD CLI and the AsyncAPI tools preinstalled. It then stays up doing nothing: Podman starts a container only when the containers it depends on are running, so an exited ci-image would keep the event backends and subscribers in `Created`.

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

The event API speaks MQTT on `localhost:1883`. curl can subscribe to it (`mqtt://`, the topic URL-encoded: `/` is `%2F`, `+` is `%2B`, `#` is `%23`). `tr` turns curl's binary topic-length prefix into line breaks; Ctrl+C stops it.

```bash
MQ="mqtt://localhost:1883"; U=observer:observer-pw    # read-only demo account
# Microcks mock events: the contract's examples, every 3 s, always the same
curl -sN -u $U "$MQ/OrderEventsAPI-1.0.0-orders%2Fv1%2F%7BorderId%7D%2Fcreated" | tr -c '[:print:]' '\n'
# mqtt-backend, the implementation: OrderCreated (orderId, createdAt) every second
curl -sN -u $U "$MQ/orders%2Fv1%2F%2B%2Fcreated" | tr -c '[:print:]' '\n'
# OrderPaid (orderId, isPaid); both topics at once: orders%2Fv1%2F%23
curl -sN -u $U "$MQ/orders%2Fv1%2F%2B%2Fpaid" | tr -c '[:print:]' '\n'
```

Or, with the `demo` helper (below): `demo preflight` checks everything and ends with `READY` or a list of problems.

## Try it

After `up`, the orders repo in Gitea has the full pipeline: two PR workflows, one per API, with the same gates. Clone it **outside this project and under another name** (it is also called `devops-api-governance`, so a default clone next to or inside this folder collides with it):

```bash
mkdir -p ~/demo && cd ~/demo
git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git orders-api
cd orders-api
```

Then branch, change `contracts/orders-openapi.yaml`, `contracts/order-events-asyncapi.yaml` or both, push, and open a pull request in Gitea. Both workflows run on every PR. The five topics of the talk, each for both APIs:

| Step | Orders API (REST) | Order Events API (MQTT) |
|------|-------------------|--------------------------|
| **1 — API Catalog.** One `catalog-info.yaml` makes both APIs visible to the whole organization. | Backstage → **APIs** shows `orders-api`, discovered from Gitea; its **Definition** tab shows the contract. | `order-events-api` appears next to it, with the broker as a Resource and its producer and consumer as edges. |
| **2 — Guidelines as code.** The guidelines live in the catalog (Backstage → **Docs** → `api-guidelines`) and run as OpenLint checks in CI; every finding links to its rule. | Server URL `http://` instead of `https://`: `openlint-openapi-check` goes **red**. | A snake_case `paid_at` field: `asyncapi-lint` goes **red**. |
| **3 — Mocking & contract testing.** The contract is a live mock at once; the contract test checks the running backend against it. | `curl http://localhost:8080/rest/Orders+API/1.0.0/orders/123` answers from the contract. A required `currency` the backend doesn't return: `contract-test` goes **red**. | Microcks publishes the contract's example events. A required `currency` on `OrderCreated` the backend never sends: `contract-test` goes **red**. |
| **4 — Deploy from the contract.** The contract isn't only tested, it is deployed. | `gateway-deploy-check` generates a KrakenD config, deploys it and re-runs the contract test through the gateway (`:8090`). | `broker-policy` generates who may publish and subscribe to which topic from the contract and the catalog and applies it to Mosquitto; `demo deny` shows the broker saying no. |
| **5 — Breaking changes.** A change that breaks the clients is blocked; the later gates are skipped. | A new *required* `channel` query parameter: `breaking-changes-check` (oasdiff) goes **red**. Optional: **green**. | Removing `isPaid` from `OrderPaid`: `breaking-changes` (Apicurio, FORWARD) goes **red**. Deprecating it: **green**. |

### Follow the talk step by step

In the talk the pipeline grows one gate at a time, and every step is **one pull request for both APIs**: the merge in step 1 puts the REST and the event API in the catalog together, the PR in step 2 adds the lint gate to both workflows, and so on. The `demo` helper puts your Gitea in the state of any step and prepares the change for it, so you can replay the talk:

```bash
scripts/demo/demo install          # once: adds a `demo` command with tab completion to ~/.bashrc; open a new terminal
demo goto 1                        # Stage 1 start: contracts only, no catalog entry, no gates
demo status                        # where you are and what comes next
demo shell                         # this terminal: cd into the demo clone (~/demo/orders-api), prompt with the branch
```

Each step is then: `git switch <branch>`, `git push -u origin <branch>`, open the PR in Gitea, merge. After a merge, `demo next` prepares the next step. [`presentation/cue-card.md`](presentation/cue-card.md) lists every step on one page. `demo goto <1|2|2-red|3|3-red|4|5|5-red|kafka|end>` jumps to any step, and `demo help` lists the rest.

| Talk step | `demo goto` | The PR |
|-----------|-------------|--------|
| 1. Catalog | `1` | `catalog-info.yaml`: Backstage lists `orders-api` and `order-events-api` |
| 2. Guidelines | `2`, `2-red` | both lint gates; then `http://` and `paid_at` go red, fixed in the same PR |
| 3. Mocks and contract tests | `3`, `3-red` | both contract tests; then a required `currency` the backends don't send goes red in both |
| 4. Deploy | `4` | the KrakenD gateway and the broker policy; `curl` through KrakenD goes from 404 to 200, `demo deny` shows the broker refusing |
| 5. Breaking changes | `5`, `5-red` | both breaking-change gates; then a required `channel` and a removed `isPaid` go red |
| Same gates on Kafka | `kafka`, `end` | the Kafka repo, full pipeline: its catalog entry and an optional field are green (the Kafka API joins the catalog), a removed `isPaid` is red |

`demo goto` force-pushes the consumer repos' `main` in *your local* Gitea and closes their open PRs. It never touches this project or GitHub.

The slides simplify a few things that the demo does in more detail:

- **Topics.** The slides use one topic, `orders.order-events.v1`. The demo has one topic per event type (`orders/v1/{orderId}/created` on MQTT, `orders.order-created.v1` and `orders.order-paid.v1` on Kafka), as the Kafka ruleset requires.
- **Broker ACLs.** The step 4 slide shows Strimzi `KafkaUser` resources. The demo runs plain Kafka, so the generated policy is applied as Kafka ACLs, and as dynamic-security roles on Mosquitto.
- **MCP.** The step 1 slide also puts MCP servers in the catalog. That part is on the slide only, and the demo has no MCP server.

---

## Events: AsyncAPI on MQTT and Kafka

The Order Events API is an AsyncAPI 3.1 contract for order events. In the orders repo it runs on **MQTT** (Mosquitto), next to the REST API; the Kafka repo runs the same kind of API on **Kafka**. The gates are the same as for REST, with tools for events:

| Gate | REST | Events |
|------|------|--------|
| 1. Catalog | Backstage, `type: openapi` | Backstage, `type: asyncapi`; the broker is a Resource, producers and consumers are edges |
| 2. Guidelines | OpenLint, `openlint-ruleset.yaml` | `asyncapi validate` + OpenLint, `asyncapi-ruleset.yaml` plus the MQTT or Kafka rules |
| 3. Contract test | Microcks over HTTP | Microcks listens on the broker and checks every event against the schema |
| 4. Deploy | KrakenD config generated from the contract | broker policy generated from the contract and the catalog: Mosquitto roles, or Kafka topics and ACLs |
| 5. Breaking changes | oasdiff | `@asyncapi/diff` on the structure + Apicurio Registry compatibility on the payloads |

Backstage lists the REST and the event APIs side by side, and the API guidelines in TechDocs hold the general, REST, async, MQTT and Kafka rules in one document; every lint finding, REST or events, links to its section.

```bash
mkdir -p ~/demo && cd ~/demo
git clone http://demo:demo12345@localhost:3000/governance-demo/order-events-kafka-api.git    # Kafka
```

The whole event side, gate by gate, with its troubleshooting: [`docs/events.md`](docs/events.md).

---

## How it works

### Governance and consumer repositories

A product team's repo stays separate from the platform that governs it:

- **Governance** — [`governance/`](governance/): the policy (`openlint/`: the OpenAPI and AsyncAPI rulesets, custom functions, examples; `api-guidelines/`: the guidelines and their TechDocs wiring; `gateway/`: the OpenAPI→KrakenD generator; `contract-test/`, `breaking-changes/`, `broker-policy/`: the event gates) and the catalog app (`api-catalog/`). Single source of truth for the rules, published as one Gitea repo, `api-governance` ([`scripts/governance-bundle.sh`](scripts/governance-bundle.sh) picks the files).
- **Consumers** — [`example/`](example/) (the orders repo: the REST and the MQTT API) and [`example-kafka/`](example-kafka/) (the event API on Kafka): each product unit (contracts, `catalog-info.yaml`, backends) with thin PR workflows. They are **starting templates**: `gitea-seed` pushes them into fresh Gitea repos on each `up`, and **PRs happen against those Gitea repos**, never against this project.

The consumers' CI **links** the governance repo (clones it at run time) instead of copying the rules. Details: [`docs/demo-isolation.md`](docs/demo-isolation.md).

### The PR gates (REST)

The orders repo runs two PR workflows on every pull request: `pr-governance.yml` for the REST API (below) and `pr-governance-events.yml` for the event API, described in [`docs/events.md`](docs/events.md). `example/.gitea/workflows/pr-governance.yml` runs four gates **in order**, each gated by `needs:`, so a failure stops the rest:

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
| `example/` | The orders repo template: `contracts/orders-openapi.yaml` and `contracts/order-events-asyncapi.yaml`, one `catalog-info.yaml`, `backend/` (REST), `events-backend/` and `events-subscriber/` (MQTT), `.gitea/workflows/pr-governance.yml` (REST), `pr-governance-events.yml` and `main-publish.yml` (events). |
| `example-kafka/` | The Kafka repo template: AsyncAPI contract, `catalog-info.yaml`, `backend/`, `subscriber/`, PR and publish workflows. |
| `governance/` | `openlint/`, `api-guidelines/`, `gateway/` (generator + `deployer/` sidecar that deploys configs to KrakenD), `contract-test/`, `breaking-changes/`, `broker-policy/` (generator + `deployer/` that applies it to the brokers), `api-catalog/` (Backstage). |
| `mosquitto/` | The MQTT broker's config, demo accounts and policy bootstrap. |
| `ci-image/` | The CI job image. |
| `runner-config.yaml` | Puts CI job containers on `gitea-network` and in the CI image. |
| `scripts/` | Seed scripts and the governance bundle; `scripts/demo/` is the `demo` helper. |
| `presentation/` | The talk as a PDF (demo clips embedded) and the demo's screenplay ([`presentation/README.md`](presentation/README.md)); `presentation/events/`: the broker policy animation and the notes of the event demo as it was recorded on its own. |
| `docs/`, `tests/` | Design notes, the event guide ([`docs/events.md`](docs/events.md)) and scripted PR scenarios (REST and events). |
| `gitea-data/`, `runner-data/` | Local runtime state, git-ignored, disposable. |

---

## Troubleshooting

**Both engines**
- **A port is already in use:** another service (or another copy of this stack) uses 3000, 2222, 7007, 8080, 8081, 8090, 1883 or 8280. Stop it, then `up` again.
- **Changes you made in Gitea's `main` disappeared:** every `up` runs `gitea-seed`, which force-pushes `example/` and `example-kafka/` over the consumer repos' `main`. If you use `demo`, run `demo goto <step>` after `up`.
- **Backstage doesn't list the API yet:** wait ~10 s after the merge and reload; `demo refresh-catalog` forces a rescan.
- **A CI job fails before any step ran:** the runner couldn't start the job container. Check `docker logs gitea-runner` / `podman logs gitea-runner`, then use **Re-run** on the run page.

**Docker**
- **Docker Desktop:** give it ~6 GB of memory; the Backstage build can fail with less.
- **Apple Silicon:** all images are available for arm64, and the CI image installs arm64 tools.

**Podman**
- **`gitea-seed` fails or the runner never registers:** the socket isn't reachable. Check `systemctl --user status podman.socket` and that `.env` holds your user id (`id -u`) in `DOCKER_SOCK`.
- **Restarting `backstage` or `gitea-runner` wipes your Gitea `main`:** Podman starts their dependency `gitea-seed` again (Docker doesn't). With `demo`, run `demo goto <step>` afterwards.
- **`backend` can't be recreated** while `krakend` runs ("has dependent containers").
- **A container stays in Created after `up`** ("container state improper", "internal libpod error"): Podman starts a dependent's exited one-shot dependencies again, and fails when one of them depends on another exited one-shot. That is why `ci-image` stays up: keep every `*-seed` free of `depends_on` on a container that exits.

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
