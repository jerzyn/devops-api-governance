# DevOps-Driven Async API Governance (demo)

The event-driven sibling of [devops-api-governance](https://github.com/jerzyn/devops-api-governance): API governance built into the delivery loop, for an **MQTT** API described with **AsyncAPI 3.1.0**, running entirely on your laptop. Kafka joins in a later stage.

An AsyncAPI contract goes through pull requests in a local Git server, next to a running broker, a provider that publishes the events and a consumer that reads them:

- **Gitea** + **Gitea Actions** (`act_runner`): local Git server, pull requests and CI.
- **Eclipse Mosquitto**: the MQTT broker.
- **Microcks** (+ async minion): mock events from the contract, and async contract tests.
- **Backstage**: the API catalog (AsyncAPI entries arrive in Stage 2).

> **Status: Stage 1 (scaffold).** The platform runs, the backend publishes events, and the PR workflow validates changed contracts. The governance gates (lint, contract test, broker policy, breaking changes) arrive stage by stage; see [Build plan](#build-plan).

---

## Requirements

Same as the REST demo: Docker (Docker Desktop, or Engine with the Compose plugin) or rootless Podman with `podman-compose`; `git`, `curl`, `bash`; internet on the first start to pull images and build the CI image.

Host ports are shifted from the REST demo so both can run at once:

| Service | Port | Notes |
|---------|------|-------|
| Gitea | http://localhost:3100 | sign in as `demo` / `demo12345` |
| MQTT (Mosquitto) | `localhost:1883` | plain MQTT, anonymous in Stage 1 |
| Microcks | http://localhost:8180 | profile `contract` |
| Backstage | http://localhost:7107 | profile `catalog` |

## Start

```bash
git clone https://github.com/jerzyn/devops-async-api-governance.git
cd devops-async-api-governance
docker compose up -d                                         # platform, broker, backend, subscriber
docker compose --profile contract --profile catalog up -d    # + Microcks and Backstage
```

With Podman, follow the REST demo: enable the Podman socket and set `DOCKER_SOCK` in `.env` (see [`.env.example`](.env.example)).

`up` seeds Gitea: the admin user, the `async-governance-demo` organization, the consumer repo `order-events-api` (from [`example/`](example/)) and the governance repo `async-api-governance` (from [`governance/`](governance/)), and the CI runner's token. With the `contract` profile it also imports the contract into Microcks.

### Check that it runs

```bash
# The backend's events on the broker
docker exec async-mosquitto mosquitto_sub -t 'orders/v1/+/events' -v -C 4

# What the subscriber received
docker compose logs -f subscriber

# Microcks mock events (profile contract): published every few seconds
docker exec async-mosquitto mosquitto_sub -t 'OrderEventsAPI-1.0.0-orders/v1/{orderId}/events' -C 2
```

To publish contract-violating events (for the contract test gate later):

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

In Stage 1 the PR workflow has one job, `asyncapi-validate`: it validates every changed AsyncAPI file and goes red on an invalid contract (try `action: publish`, a v2 keyword, in an operation).

## How it works

### Two repositories

As in the REST demo, a product team's repo stays separate from the platform that governs it:

- **Governance**: [`governance/`](governance/): the AsyncAPI ruleset (`spectral/`), the API guidelines (`api-guidelines/`) and the catalog app (`api-catalog/`).
- **Consumer**: [`example/`](example/): the AsyncAPI contract, the backend, the subscriber and a thin PR workflow. `gitea-seed` pushes it into a fresh Gitea repo on each `up`, and PRs happen against that Gitea repo.

### The contract

[`example/contracts/order-events-asyncapi.yaml`](example/contracts/order-events-asyncapi.yaml) describes the Order Events API: the backend sends `OrderCreated` and `OrderPaid` on `orders/v1/{orderId}/events`. Two conventions come from the tooling spike (Stage 0):

- **One message per operation, and every operation has an `mqtt` binding.** Microcks mocks one example per operation, and only operations with an MQTT binding.
- **Payload schemas stay open** (no `additionalProperties: false`), so adding an optional field to an event is not a breaking change for consumers.

### CI image

CI jobs run in `localhost/devops-async-api-governance-ci:latest` ([`ci-image/Dockerfile`](ci-image/Dockerfile)): Node 24 with the AsyncAPI CLI, parser and diff, OpenLint and the `mqtt` command line client preinstalled, analytics off.

## Build plan

| Stage | What it adds | State |
|-------|--------------|-------|
| 0 | Tooling spike on AsyncAPI 3.x | done |
| 1 | Scaffold: platform, broker, contract, backend, subscriber, PR workflow skeleton | **this** |
| 2 | Catalog: `type: asyncapi` in Backstage | |
| 3 | Guidelines as code: Async + MQTT rules (OpenLint) | |
| 4 | Mock and contract test (Microcks async) | |
| 5 | Broker policy: Mosquitto ACL generated from the contract | |
| 6 | Breaking changes: `@asyncapi/diff` + Apicurio compatibility | |
| 7 | Kafka + Apicurio Registry | |
| 8 | Demo helper, scenarios, docs | |

## Stop / reset

```bash
docker compose --profile contract --profile catalog down       # stop
docker compose --profile contract --profile catalog down -v    # + drop the seed volume
rm -rf gitea-data runner-data                                  # + drop Gitea and runner state
```

## Security note

A local demo: `gitea-seed` and `gitea-runner` get the container engine socket, and the broker accepts anonymous clients in Stage 1. Fine on a laptop, not a pattern for shared infrastructure.

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See [LICENSE](LICENSE).
