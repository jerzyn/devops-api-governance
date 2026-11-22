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

## Catalog

Backstage discovers `catalog-info.yaml` from Gitea, so both APIs are visible
to the whole organisation. Merging a change to it updates their catalog entries.

## PR loop

1. Branch, edit a contract (and its backend if needed).
2. Push, open a PR into `main` in Gitea (`http://localhost:3000`, `demo` / `demo12345`).
3. Merge. There are no automated checks yet.
4. Backstage re-discovers `catalog-info.yaml` and updates the API entities.
