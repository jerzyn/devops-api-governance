# Order Events API: consumer repo

The Order Events API: its AsyncAPI contract, the backend that publishes the
events and a subscriber that consumes them, owned by the platform team.

## Contents

| Path | Purpose |
|------|---------|
| `contracts/order-events-asyncapi.yaml` | The AsyncAPI 3.1.0 contract (source of truth for the API). |
| `backend/` | The provider: publishes `OrderCreated` and `OrderPaid` on `orders/v1/{orderId}/created` and `orders/v1/{orderId}/paid`. |
| `subscriber/` | A consumer: subscribes to `orders/v1/+/created` and `orders/v1/+/paid` and logs every event. |

## PR loop

1. Branch, edit `contracts/order-events-asyncapi.yaml` (and the backend if needed).
2. Push, open a PR into `main` in Gitea (http://localhost:3100, `demo` / `demo12345`).
3. Merge. There are no automated checks yet.
