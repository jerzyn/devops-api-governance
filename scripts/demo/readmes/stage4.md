# Orders: consumer repo

The orders team's APIs, side by side: the **Orders API** (REST, OpenAPI) and the
**Order Events API** (events on MQTT, AsyncAPI), with the backends that
implement them. It is the unit a product team owns and opens pull requests
against, and every pull request is governed for both APIs at once.

## Contents

| Path | Purpose |
|------|---------|
| `contracts/orders-openapi.yaml` | The OpenAPI contract of the Orders API (source of truth). |
| `contracts/order-events-asyncapi.yaml` | The AsyncAPI 3.1.0 contract of the Order Events API (source of truth). |
| `catalog-info.yaml` | Backstage entities: both APIs, their providers and consumer, the broker, the system and the team. |
| `backend/` | The Orders API provider. Runs at `http://localhost:8081`. |
| `events-backend/` | The Order Events API provider: publishes `OrderCreated` and `OrderPaid` on `orders/v1/{orderId}/created` and `orders/v1/{orderId}/paid`. |
| `events-subscriber/` | A consumer: subscribes to `orders/v1/+/created` and `orders/v1/+/paid` and logs every event. |
| `.gitea/workflows/pr-governance.yml` | The PR gates for the Orders API (below). |
| `.gitea/workflows/pr-governance-events.yml` | The PR gates for the Order Events API (below). |

## PR gates

Every pull request runs both workflows, the same gates for each API. In each
workflow a gate runs only when the one before it passed.

| Gate | Orders API (REST) | Order Events API (MQTT) |
|------|-------------------|--------------------------|
| Guidelines | **openlint-openapi-check**: lints the changed OpenAPI files against the linked governance ruleset; fails on error-severity findings. | **asyncapi-lint**: is the contract valid AsyncAPI, and does it follow the async and MQTT API guidelines? Each finding links to its guideline. |
| Contract test | **contract-test**: imports the PR's contract into Microcks and tests the running `backend` against it; fails on drift. | **contract-test**: Microcks listens on every topic the API sends to and checks each event the running `events-backend` publishes against the contract. |
| Deploy | **gateway-deploy-check**: generates a KrakenD config from the PR's contract, deploys it to the running gateway and re-runs the contract test through it. | **broker-policy**: who may publish and subscribe to which topic, generated from the contract and the catalog, applied to the broker and checked from the outside. |

## PR loop

1. Branch, edit a contract (and its backend if needed).
2. Push, open a PR into `main` in Gitea (`http://localhost:3000`, `demo` / `demo12345`).
3. The gates run on the PR for both APIs; merge when they are green.
4. Backstage re-discovers `catalog-info.yaml` and updates the API entities.
