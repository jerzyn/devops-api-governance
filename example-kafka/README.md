# Order Events Kafka API: consumer repo

The Order Events API on Kafka: its AsyncAPI contract, the backend that
publishes the events and a subscriber that consumes them, owned by the
platform team. The same gates run here as for the MQTT API in the orders repo; only
the workflow's environment differs.

## Contents

| Path | Purpose |
|------|---------|
| `contracts/order-events-kafka-asyncapi.yaml` | The AsyncAPI 3.1.0 contract: topics `orders.order-created.v1` and `orders.order-paid.v1`, with Kafka bindings (partitions, retention, message key). |
| `backend/` | The provider: publishes `OrderCreated` and `OrderPaid` keyed by the order id, and checks every event against the topic's latest schema in Apicurio before sending (logs `REJECTED by the registry schema` otherwise). |
| `subscriber/` | A consumer: reads both topics in consumer group `orders-kafka-subscriber` and logs every event; logs `DENIED` when the broker policy refuses it. |
| `catalog-info.yaml` | The API, its provider and consumer, the Kafka cluster and the schema registry, for Backstage and the broker policy. |
| `.gitea/workflows/pr-governance.yml` | The PR gates: lint, breaking changes, contract test, broker policy. |
| `.gitea/workflows/main-publish.yml` | After a merge: register the schemas, apply main's broker policy (topics and ACLs). |
