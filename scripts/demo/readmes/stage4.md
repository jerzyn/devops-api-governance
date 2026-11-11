# Order Events API: consumer repo

The Order Events API: its AsyncAPI contract, the backend that publishes the
events and a subscriber that consumes them, owned by the platform team.

## Contents

| Path | Purpose |
|------|---------|
| `contracts/order-events-asyncapi.yaml` | The AsyncAPI 3.1.0 contract (source of truth for the API). |
| `backend/` | The provider: publishes `OrderCreated` and `OrderPaid` on `orders/v1/{orderId}/created` and `orders/v1/{orderId}/paid`. |
| `subscriber/` | A consumer: subscribes to `orders/v1/+/created` and `orders/v1/+/paid` and logs every event. |
| `catalog-info.yaml` | Backstage entities: the API, its provider and consumer, the broker. |
| `.gitea/workflows/pr-governance.yml` | The PR gates (below). |

## PR gates

Each gate runs only when the one before it passed:

1. **asyncapi-lint**: is the contract valid AsyncAPI, and does it follow the async and MQTT API guidelines? Each finding links to its guideline.
2. **contract-test**: Microcks listens on every topic the API sends to and checks each event the running backend publishes against the contract.
3. **broker-policy**: who may publish and subscribe to which topic, generated from the contract and the catalog, applied to the broker and checked from the outside.

## PR loop

1. Branch, edit `contracts/order-events-asyncapi.yaml` (and the backend if needed).
2. Push, open a PR into `main` in Gitea (http://localhost:3100, `demo` / `demo12345`).
3. The gates run on the PR; merge when they are green.
