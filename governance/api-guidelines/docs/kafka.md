# Kafka API Guidelines

These rules apply to APIs whose servers use Kafka.

---

## [Topic Naming (api-peak:kafka1:2026-topic-naming)](#kafka-topic-naming)

Channel addresses (Kafka topics) **MUST** be named `<domain>.<event-name>.v<MAJOR>`: lowercase words made of letters, digits and hyphens, separated by `.`, ending in the major version. Topics **MUST NOT** contain parameters: Kafka has no topic hierarchy, so the entity id goes into the message key instead (see [Message Key](#kafka-message-key)).

A breaking change publishes to a new topic version, next to the old topic.

#### Example

```yaml
channels:
  orderCreated:
    address: orders.order-created.v1     # breaking change: orders.order-created.v2
```

---

## [One Event Type per Topic (api-peak:kafka2:2026-one-event-type-per-topic)](#kafka-one-event-type-per-topic)

Every channel (topic) **MUST** carry exactly one message type. The schema registry keys a payload schema by topic, so one topic has one schema and one compatibility rule, and a contract test listening on a topic knows which schema applies.

#### Example

```yaml
channels:
  orderCreated:
    address: orders.order-created.v1
    messages:
      orderCreated:
        $ref: '#/components/messages/OrderCreated'
  orderPaid:
    address: orders.order-paid.v1
    messages:
      orderPaid:
        $ref: '#/components/messages/OrderPaid'
```

---

## [Message Key (api-peak:kafka3:2026-message-key)](#kafka-message-key)

Every message **MUST** declare its key in `bindings.kafka.key`. Kafka keeps order only within a partition, and the key picks the partition: keying every event of an entity by its id (for example the order id) delivers that entity's events in order.

#### Example

```yaml
components:
  messages:
    OrderCreated:
      bindings:
        kafka:
          key:
            type: string
            description: The order id; all events of one order land on one partition, in order.
          bindingVersion: 0.5.0
```

---

## [Partitions (api-peak:kafka4:2026-partitions)](#kafka-partitions)

Every channel **MUST** declare `bindings.kafka.partitions`. The partition count limits how many consumers of one group read in parallel, and the broker policy creates the topic from it. The count **MAY** grow later; it **MUST NOT** shrink, which Kafka does not allow.

#### Example

```yaml
channels:
  orderCreated:
    bindings:
      kafka:
        partitions: 3
        replicas: 1
        bindingVersion: 0.5.0
```

---

## [Retention (api-peak:kafka5:2026-retention)](#kafka-retention)

Every channel **SHOULD** declare its retention in `bindings.kafka.topicConfiguration` (`retention.ms`). Consumers need to know how far back they can replay events after an outage.

#### Example

```yaml
channels:
  orderCreated:
    bindings:
      kafka:
        topicConfiguration:
          retention.ms: 604800000   # 7 days
          cleanup.policy: [delete]
        bindingVersion: 0.5.0
```

---

## [Secure Transport (api-peak:kafka6:2026-secure-transport)](#kafka-secure-transport)

Servers **MUST** use `kafka-secure` (Kafka over TLS). Plain `kafka` is allowed only for a local development broker (`localhost`, `127.0.0.1` or the demo's `kafka`).

#### Example

```yaml
servers:
  production:
    host: kafka.example.com:9093
    protocol: kafka-secure
  local:
    host: kafka:9092
    protocol: kafka           # allowed: the local demo broker
```
