# Async API Guidelines

The API Peak async guidelines define the standards for event-driven APIs described with AsyncAPI. They apply together with the General API Guidelines above. Every rule below is checked automatically: its identifier is the rule name in the linter ruleset (`asyncapi-ruleset.yaml` in the governance repository), and every finding links back to its section here.

---

## [AsyncAPI Specification (api-peak:async1:2026-asyncapi)](#asyncapi-specification)

An event-driven API **MUST** be described using the AsyncAPI specification, version **3.x**. The AsyncAPI document is the contract between the producer and its consumers (see [Contract](index.md#contract-api-peakgeneral62025-contract)).

#### Example

```yaml
asyncapi: 3.1.0
info:
  title: Order Events API
  version: 1.0.0
```

---

## [API Title (api-peak:async2:2026-api-title)](#api-title)

`info.title` **MUST** be written in Title Case and **MUST** end with the word `API`, for example `Order Events API`.

#### Example

```yaml
info:
  title: Order Events API      # not "order events" or "Order Events"
```

---

## [API Version (api-peak:async3:2026-api-version)](#api-version)

`info.version` **MUST** follow Semantic Versioning (`MAJOR.MINOR.PATCH`), see [Semver](index.md#semver-api-peakgeneral52025-semver). A breaking change to any channel, operation or payload requires a new MAJOR version.

#### Example

```yaml
info:
  version: 1.2.0   # 1.1.0 -> 1.2.0: an optional field was added
                   # 1.2.0 -> 2.0.0: a field was removed (breaking)
```

---

## [Contact and Ownership (api-peak:async4:2026-contact)](#contact)

`info.contact` **SHOULD** name the owning team and give a `url` and an `email`, so that a consumer who sees an unexpected event knows whom to ask.

#### Example

```yaml
info:
  contact:
    name: Platform team
    url: http://localhost:7007/catalog/default/group/platform-team
    email: platform-team@example.com
```

---

## [Operation Summary (api-peak:async5:2026-operation-summary)](#operation-summary)

Every operation **MUST** have a `summary` that starts with a capital letter and is at most 75 characters long. A longer explanation belongs in `description`.

#### Example

```yaml
operations:
  sendOrderCreated:
    summary: Publish an order created event
    description: Sent once, when the backend accepts a new order.
```

---

## [Operation Naming (api-peak:async6:2026-operation-naming)](#operation-naming)

Operation identifiers **SHOULD** be camelCase and start with the action they describe: `send` or `receive`, for example `sendOrderCreated`.

#### Example

```yaml
operations:
  sendOrderCreated:     # not "publishOrder" or "order_created"
    action: send
  receiveOrderCancelled:
    action: receive
```

---

## [One Message per Operation (api-peak:async7:2026-one-message-per-operation)](#one-message-per-operation)

An operation **MUST** reference exactly one message. A channel may carry several message types, but each one gets its own operation, so that bindings, documentation, mocks and contract tests apply to one event type at a time.

#### Example

```yaml
operations:
  sendOrderCreated:
    action: send
    channel:
      $ref: '#/channels/orderCreated'
    messages:
      - $ref: '#/channels/orderCreated/messages/orderCreated'   # exactly one
```

---

## [Messages from Own Channel (api-peak:async15:2026-own-channel-messages)](#own-channel-messages)

An operation **MUST** only reference messages defined on its own channel (`$ref: '#/channels/<its channel>/messages/...'`). A message borrowed from another channel would be published on a topic whose contract does not describe it, so mocks, contract tests and the broker policy would all look at the wrong topic.

#### Example

```yaml
operations:
  sendOrderPaid:
    channel:
      $ref: '#/channels/orderPaid'
    messages:
      - $ref: '#/channels/orderPaid/messages/orderPaid'   # its own channel
```

---

## [Message Metadata (api-peak:async8:2026-message-metadata)](#message-metadata)

Every message **MUST** have a `name` in PascalCase (the event type, for example `OrderCreated`), a human readable `title`, a `contentType` and a `payload`.

#### Example

```yaml
components:
  messages:
    OrderCreated:
      name: OrderCreated
      title: Order created
      contentType: application/json
      payload:
        $ref: '#/components/schemas/OrderCreatedPayload'
```

---

## [Message Description (api-peak:async16:2026-message-description)](#message-description)

Every message **MUST** have a `description`: when it is sent and what it means for a consumer. A consumer, human or agent, reads the contract and nothing else, so a message without a description leaves it guessing.

#### Example

```yaml
components:
  messages:
    OrderCreated:
      name: OrderCreated
      title: Order created
      description: Sent once, when the backend accepts a new order.
```

---

## [Message Examples (api-peak:async9:2026-message-examples)](#message-examples)

Every message **MUST** have at least one example. Examples drive the mock events and are the first thing a consumer reads.

#### Example

```yaml
components:
  messages:
    OrderCreated:
      examples:
        - name: newOrder
          payload:
            orderId: '123'
            createdAt: '2026-11-11T10:00:00Z'
```

---

## [JSON Payloads (api-peak:async10:2026-json-payloads)](#json-payloads)

Payloads **MUST** be JSON (`application/json`), described with JSON Schema, see [JSON](index.md#json-api-peakgeneral112025-json). Correlation and tracing data, such as a correlation id, **SHOULD** travel in message headers, not in the payload.

#### Example

```yaml
components:
  messages:
    OrderCreated:
      contentType: application/json
      headers:
        type: object
        properties:
          correlationId:
            type: string
            description: Id of the request that caused the event.
      payload:
        $ref: '#/components/schemas/OrderCreatedPayload'
```

---

## [Property Naming (api-peak:async11:2026-property-naming)](#property-naming)

Payload property names **MUST** be camelCase, for example `orderId` or `createdAt`.

#### Example

```yaml
components:
  schemas:
    OrderPaidPayload:
      type: object
      properties:
        orderId:          # not order_id
          type: string
        paidAt:           # not paid_at
          type: string
          format: date-time
```

---

## [Schema Naming (api-peak:async12:2026-schema-naming)](#schema-naming)

Names of reusable schemas under `components.schemas` **SHOULD** be PascalCase, for example `OrderCreatedPayload`.

#### Example

```yaml
components:
  schemas:
    OrderCreatedPayload:    # not orderCreatedPayload or order_created_payload
      type: object
```

---

## [Open Payload Schemas (api-peak:async13:2026-open-payloads)](#open-payloads)

Payload schemas **MUST NOT** set `additionalProperties: false`. Producers add optional fields over time; a closed schema would turn every such addition into a breaking change for consumers. Consumers **MUST** ignore fields they do not know, see [Robustness](index.md#robustness-api-peakgeneral72025-robustness).

#### Example

```yaml
components:
  schemas:
    OrderCreatedPayload:
      type: object
      required: [orderId, createdAt]
      properties:
        orderId:
          type: string
        createdAt:
          type: string
          format: date-time
      # no additionalProperties: false
```

---

## [Compatibility (api-peak:async14:2026-compatibility)](#compatibility)

A change to a published API **MUST NOT** break its existing consumers. For an event the API sends, these are breaking:

- changing or removing a topic, an operation or a channel, or flipping an operation's action;
- changing the MQTT `qos` or `retain` of an operation;
- a payload that consumers built on the previous schema cannot read: removing a field, changing a field's type, or narrowing an allowed value.

Adding an optional or required field to an event is not breaking: consumers ignore what they do not know (see [Open Payload Schemas](#open-payload-schemas-api-peakasync132026-open-payloads)).

A breaking change **MUST** be published as a new MAJOR version on a new topic version (for example `orders/v2/...` on MQTT, `orders.order-created.v2` on Kafka), next to the old one, until its consumers have moved.

The PR gate checks the structure with `@asyncapi/diff` and every payload against the schema registry. The registry rule follows who reads the payload: **FORWARD** for events the API sends, **BACKWARD** for messages it receives.

#### Example

Not breaking: a new optional field.

```yaml
OrderPaidPayload:
  required: [orderId, isPaid]
  properties:
    orderId: { type: string }
    isPaid: { type: boolean }
    paidAt: { type: string, format: date-time }   # added
```

Breaking: a field consumers read is removed. Publish it on `orders/v2/{orderId}/paid` (Kafka: `orders.order-paid.v2`) as version `2.0.0`, next to v1.

```yaml
OrderPaidPayload:
  required: [orderId]
  properties:
    orderId: { type: string }
    # isPaid removed
```

---
