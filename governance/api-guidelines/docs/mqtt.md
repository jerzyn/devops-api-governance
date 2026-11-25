# MQTT API Guidelines

These rules apply to APIs whose servers use MQTT.

---

## [Topic Naming (api-peak:mqtt1:2026-topic-naming)](#topic-naming)

Channel addresses (MQTT topics) **MUST** consist of lowercase levels made of letters, digits and hyphens, separated by `/`. A level **MAY** be a parameter written as `{camelCase}`. Topics **MUST NOT** start or end with `/`, **MUST NOT** contain the wildcards `+` or `#`, and **MUST NOT** start with `$` (reserved for broker system topics).

#### Example

```yaml
channels:
  orderCreated:
    address: orders/v1/{orderId}/created
```

---

## [Topic Versioning (api-peak:mqtt2:2026-topic-version)](#topic-version)

Every topic **MUST** contain a major version level `v{MAJOR}`, for example `orders/v1/...`. A breaking change publishes to a new version level, so that existing subscribers keep receiving the events they understand.

#### Example

```yaml
channels:
  orderCreated:
    address: orders/v1/{orderId}/created     # breaking change: orders/v2/{orderId}/created
```

---

## [Quality of Service (api-peak:mqtt3:2026-qos)](#qos)

Every operation **MUST** declare its MQTT quality of service in `bindings.mqtt.qos`. Consumers size their deduplication and retry logic from it.

#### Example

```yaml
operations:
  sendOrderCreated:
    bindings:
      mqtt:
        qos: 1      # at least once: consumers deduplicate by orderId
```

---

## [One Event Type per Topic (api-peak:mqtt6:2026-one-event-type-per-topic)](#one-event-type-per-topic)

Every channel (topic) **MUST** carry exactly one message type. MQTT has no standard header for the event type, so subscribers choose the events they want by topic (for example `orders/v1/+/paid`), and a contract test listening on a topic knows which schema applies. Related event types share a topic prefix instead: `orders/v1/{orderId}/created`, `orders/v1/{orderId}/paid`.

#### Example

```yaml
channels:
  orderCreated:
    address: orders/v1/{orderId}/created
    messages:
      orderCreated:
        $ref: '#/components/messages/OrderCreated'
  orderPaid:
    address: orders/v1/{orderId}/paid
    messages:
      orderPaid:
        $ref: '#/components/messages/OrderPaid'
```

---

## [Retained Messages (api-peak:mqtt4:2026-retain)](#retain)

Every operation **SHOULD** declare `bindings.mqtt.retain`. Events (something happened) are not retained; state (the latest value of something) may be.

#### Example

```yaml
operations:
  sendOrderCreated:
    bindings:
      mqtt:
        qos: 1
        retain: false   # an event, not state
```

---

## [Secure Transport (api-peak:mqtt5:2026-secure-transport)](#secure-transport)

Servers **MUST** use `secure-mqtt` (MQTT over TLS). Plain `mqtt` is allowed only for a local development broker (`localhost`, `127.0.0.1` or the demo's `mosquitto`).

#### Example

```yaml
servers:
  production:
    host: broker.example.com:8883
    protocol: secure-mqtt
  local:
    host: mosquitto:1883
    protocol: mqtt          # allowed: the local demo broker
```

---
