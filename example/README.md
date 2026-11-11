# Order Events API: consumer repo

The Order Events API: its AsyncAPI contract, the backend that publishes the
events and a subscriber that consumes them, owned by the platform team.

## Contents

| Path | Purpose |
|------|---------|
| `contracts/order-events-asyncapi.yaml` | The AsyncAPI 3.1.0 contract (source of truth for the API). |
| `backend/` | The provider: publishes `OrderCreated` and `OrderPaid` on `orders/v1/{orderId}/events`. |
| `subscriber/` | A consumer: subscribes to `orders/v1/+/events` and logs every event. |
| `.gitea/workflows/pr-governance.yml` | The PR workflow. Stage 1: validates changed contracts. |
