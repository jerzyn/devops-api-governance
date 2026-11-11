# DevOps-Driven Async API Governance (demo)

The event-driven sibling of [devops-api-governance](https://github.com/jerzyn/devops-api-governance): API governance built into the delivery loop, for an **MQTT** API described with **AsyncAPI 3.1.0**, running entirely on your laptop. Kafka joins in a later stage.

An AsyncAPI contract goes through pull requests in a local Git server, next to a running broker, a provider that publishes the events and a consumer that reads them:

- **Gitea** + **Gitea Actions** (`act_runner`): local Git server, pull requests and CI.
- **Eclipse Mosquitto**: the MQTT broker, with a broker policy generated from the contract and the catalog.
- **Microcks** (+ async minion): mock events from the contract, and async contract tests.
- **Apicurio Registry**: the payload schema of every topic, with compatibility rules.
- **Backstage**: the API catalog, with the contract rendered as AsyncAPI docs.

> **Status: Stage 6 (breaking changes).** The platform runs, the backend publishes events, Backstage lists the API with its producer, consumer and broker, and the PR workflow validates changed contracts, lints them against the async and MQTT API guidelines checks it for breaking changes (structure and payload compatibility in Apicurio), contract-tests the running backend in Microcks, and applies a broker policy generated from the contract and the catalog. Kafka is next; see [Build plan](#build-plan).

---

## Requirements

Same as the REST demo: Docker (Docker Desktop, or Engine with the Compose plugin) or rootless Podman with `podman-compose`; `git`, `curl`, `bash`; internet on the first start to pull images and build the CI image.

Host ports are shifted from the REST demo so both can run at once:

| Service | Port | Notes |
|---------|------|-------|
| Gitea | http://localhost:3100 | sign in as `demo` / `demo12345` |
| MQTT (Mosquitto) | `localhost:1883` | plain MQTT; demo accounts in [`mosquitto/users.txt`](mosquitto/users.txt) |
| Microcks | http://localhost:8180 | profile `contract` |
| Apicurio Registry | http://localhost:8280 | REST API at `/apis/registry/v3` |
| Backstage | http://localhost:7107 | profile `catalog` |

## Start

```bash
git clone https://github.com/jerzyn/devops-async-api-governance.git
cd devops-async-api-governance
docker compose up -d                                         # platform, broker, backend, subscriber
docker compose --profile contract --profile catalog up -d    # + Microcks and Backstage
```

With Podman, follow the REST demo: enable the Podman socket and set `DOCKER_SOCK` in `.env` (see [`.env.example`](.env.example)).

`up` seeds Gitea: the admin user, the `async-governance-demo` organization, the consumer repo `order-events-api` (from [`example/`](example/)) and the governance repo `async-api-governance` (from [`governance/`](governance/)), and the CI runner's token. `broker-policy-seed` applies the broker policy for the contract on `main`, and `registry-seed` registers its payload schemas in Apicurio. With the `contract` profile, `microcks-seed` also imports the contract into Microcks.

### Check that it runs

```bash
# The backend's events on the broker (observer: a read-everything demo account)
docker exec async-mosquitto mosquitto_sub -u observer -P observer-pw -t 'orders/v1/#' -v -C 4

# What the subscriber received
docker compose logs -f subscriber

# Microcks mock events (profile contract): published every few seconds
docker exec async-mosquitto mosquitto_sub -u observer -P observer-pw -t 'OrderEventsAPI-1.0.0-orders/v1/{orderId}/created' -C 2
```

To publish contract-violating events (the contract test gate goes red):

```bash
BACKEND_DRIFT=true docker compose up -d backend   # drifted events
docker compose up -d backend                      # back to conformant
```

## Try it

Clone the consumer repo from Gitea outside this project, branch, change `contracts/order-events-asyncapi.yaml`, push, and open a pull request in Gitea:

```bash
mkdir -p ~/demo && cd ~/demo
git clone http://demo:demo12345@localhost:3100/async-governance-demo/order-events-api.git
```

The PR workflow's first gate, `asyncapi-lint`, checks every changed AsyncAPI file in two steps:

1. `asyncapi validate`: is it a valid AsyncAPI document? Try `action: publish` (a v2 keyword) in an operation.
2. `openlint lint` against the central ruleset: does it follow the API guidelines? Try renaming the topic to `Orders/{orderId}/events` (uppercase, no version level) or adding `additionalProperties: false` to a payload schema.

Each lint finding names its guideline rule and links to that section of the API guidelines in Backstage TechDocs. To see every rule fire at once, lint the intentionally broken example locally:

```bash
docker run --rm -v "$PWD:/w" -w /w localhost/devops-async-api-governance-ci:latest \
  openlint lint -r governance/spectral/asyncapi-ruleset.yaml governance/spectral/examples/asyncapi-invalid.yaml
```

When lint passes, the second gate, `breaking-changes`, compares every modified contract with `main`:

1. **Structure**, with `@asyncapi/diff`: a changed or removed topic, a removed operation, a flipped `send`/`receive`, a changed `qos` or `retain` is breaking. Try changing `orders/v1/{orderId}/paid` to `.../payment`.
2. **Payloads**, against Apicurio: each topic's payload schema is an artifact with a compatibility rule, FORWARD for events the API sends. The gate asks the registry whether the PR's schema would be accepted as the next version (dry run). Removing `isPaid` or making it a string fails; adding an optional `paidAt` passes.

After a merge, the `Publish API (main)` workflow registers the new schemas, so the next PR is compared with them, and applies `main`'s broker policy.

The third gate, `contract-test`, checks the running backend against the PR's contract. It imports the contract into Microcks, then for every `send` operation listens on that operation's topic (`orders/v1/+/created`, `orders/v1/+/paid`) for a few seconds and validates every message against the payload schema. It fails when a message does not match, or when no message arrives at all. It needs the `contract` profile. To see it go red without touching the contract, run the backend with drift (`BACKEND_DRIFT=true docker compose up -d backend`) and re-run the PR's workflow; or, in a PR, make a field the backend does not send required.

You can run the same test from your machine:

```bash
docker run --rm --network async-gitea-network -v "$PWD:/w" -w /w localhost/devops-async-api-governance-ci:latest \
  node governance/contract-test/async-contract-test.js example/contracts/order-events-asyncapi.yaml
```

The fourth gate, `broker-policy`, puts the contract in charge of the broker. It generates who may publish and subscribe to which topic from the contract and the catalog, applies that to Mosquitto, checks it from the outside and re-runs the contract test under it. See [Broker policy](#broker-policy) for the moments to show live.

## How it works

### Two repositories

As in the REST demo, a product team's repo stays separate from the platform that governs it:

- **Governance**: [`governance/`](governance/): the AsyncAPI ruleset (`spectral/`), the API guidelines (`api-guidelines/`), the contract test runner (`contract-test/`), the breaking change checks (`breaking-changes/`), the broker policy generator and deployer (`broker-policy/`) and the catalog app (`api-catalog/`).
- **Consumer**: [`example/`](example/): the AsyncAPI contract, the backend, the subscriber and a thin PR workflow. `gitea-seed` pushes it into a fresh Gitea repo on each `up`, and PRs happen against that Gitea repo.

### The contract

[`example/contracts/order-events-asyncapi.yaml`](example/contracts/order-events-asyncapi.yaml) describes the Order Events API: the backend sends `OrderCreated` on `orders/v1/{orderId}/created` and `OrderPaid` on `orders/v1/{orderId}/paid`. Three conventions come from the tooling:

- **One message per operation, and every operation has an `mqtt` binding.** Microcks mocks one example per operation, and only operations with an MQTT binding.
- **One event type per topic.** Microcks validates every message on a topic against the tested operation's schema, and MQTT has no type header, so each event type gets its own topic (guideline `api-peak:mqtt6`).
- **Payload schemas stay open** (no `additionalProperties: false`), so adding an optional field to an event is not a breaking change for consumers.

### Catalog

[`example/catalog-info.yaml`](example/catalog-info.yaml) puts the event flow into Backstage (http://localhost:7107, profile `catalog`):

| Entity | Kind | Relation |
|--------|------|----------|
| `order-events-api` | API, `type: asyncapi` | definition from the contract, rendered as AsyncAPI docs |
| `orders-backend` | Component | `providesApis: order-events-api`, depends on the broker |
| `orders-subscriber` | Component | `consumesApis: order-events-api`, depends on the broker |
| `mqtt-broker` | Resource, `type: message-broker` | the Mosquitto broker |
| `orders` | System | groups all of the above |

Backstage → **APIs** → *Order Events API* → **Documentation** shows servers, operations, messages and the MQTT bindings; **Catalog Graph** shows who produces and who consumes the events. The Gitea provider rescans every 10 s, so a merged change shows up within seconds.

### Broker policy

Every client logs in, and what an account may do comes from two files the team already maintains:

- the **contract** says which topics exist and who sends on them (`send` operation: providers publish, consumers subscribe);
- the **catalog** says who provides the API (`orders-backend`) and who consumes it (`orders-subscriber`).

[`governance/broker-policy/generate-policy.js`](governance/broker-policy/generate-policy.js) turns them into a policy: the backend may publish `orders/v1/+/created` and `orders/v1/+/paid`, the subscriber may subscribe to exactly those, Microcks may read them (contract tests) and publish its mock topics. Everything else is denied. `broker-policy-deployer` applies it live through the Mosquitto [dynamic security plugin](https://mosquitto.org/documentation/dynamic-security/) in one `$CONTROL` message, and [`verify-policy.js`](governance/broker-policy/verify-policy.js) checks the result the way a client sees it.

The plugin refuses a subscription outside the policy, so the refusal is visible:

```bash
# A consumer asks for a topic the contract does not have
docker exec async-mosquitto mosquitto_sub -u orders-subscriber -P orders-subscriber-pw -t 'orders/v1/+/refunded'
# -> All subscription requests were denied.

# ... or for more than the contract gives it
docker exec async-mosquitto mosquitto_sub -u orders-subscriber -P orders-subscriber-pw -t 'orders/v1/#'
# -> All subscription requests were denied.

# Without an account
docker exec async-mosquitto mosquitto_sub -t 'orders/v1/+/paid'
# -> Connection error: Connection Refused: not authorised.
```

Take a consumer out of the catalog (drop `consumesApis` from `orders-subscriber` in a PR) and the next policy removes its access: the broker disconnects it, and `docker compose logs subscriber` shows `DENIED orders/v1/+/created, orders/v1/+/paid ... not granted by the broker policy`. A PR's workflow applies that PR's policy to the shared demo broker; `docker compose up -d broker-policy-seed` puts back the policy from `main`.

### CI image

CI jobs run in `localhost/devops-async-api-governance-ci:latest` ([`ci-image/Dockerfile`](ci-image/Dockerfile)): Node 24 with the AsyncAPI CLI, parser and diff, OpenLint and the `mqtt` command line client preinstalled, analytics off.

## Build plan

| Stage | What it adds | State |
|-------|--------------|-------|
| 0 | Tooling spike on AsyncAPI 3.x | done |
| 1 | Scaffold: platform, broker, contract, backend, subscriber, PR workflow skeleton | done |
| 2 | Catalog: `type: asyncapi` in Backstage | done |
| 3 | Guidelines as code: Async + MQTT rules (OpenLint) | done |
| 4 | Mock and contract test (Microcks async) | done |
| 5 | Broker policy: generated from the contract and the catalog | done |
| 6 | Breaking changes: `@asyncapi/diff` + Apicurio compatibility | **this** |
| 7 | Kafka + Apicurio Registry | |
| 8 | Demo helper, scenarios, docs | |

## Stop / reset

```bash
docker compose --profile contract --profile catalog down       # stop
docker compose --profile contract --profile catalog down -v    # + drop the seed volume
rm -rf gitea-data runner-data                                  # + drop Gitea and runner state
```

## Security note

A local demo: `gitea-seed` and `gitea-runner` get the container engine socket, the broker speaks plain MQTT without TLS, and the demo accounts and their passwords sit in `mosquitto/users.txt` and the workflow. Fine on a laptop, not a pattern for shared infrastructure.

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See [LICENSE](LICENSE).
