# Async API Guidelines

The API Peak async guidelines define the standards for event-driven APIs described with AsyncAPI. They apply together with the General API Guidelines above. Every rule below is checked automatically: its identifier is the rule name in the linter ruleset (`asyncapi-ruleset.yaml` in the governance repository), and every finding links back to its section here.

---

## [AsyncAPI Specification (api-peak:async1:2026-asyncapi)](#asyncapi-specification)

An event-driven API **MUST** be described using the AsyncAPI specification, version **3.x**. The AsyncAPI document is the contract between the producer and its consumers (see [Contract](index.md#contract-api-peakgeneral62025-contract)).

---

## [API Title (api-peak:async2:2026-api-title)](#api-title)

`info.title` **MUST** be written in Title Case and **MUST** end with the word `API`, for example `Order Events API`.

---

## [API Version (api-peak:async3:2026-api-version)](#api-version)

`info.version` **MUST** follow Semantic Versioning (`MAJOR.MINOR.PATCH`), see [Semver](index.md#semver-api-peakgeneral52025-semver). A breaking change to any channel, operation or payload requires a new MAJOR version.

---

## [Contact and Ownership (api-peak:async4:2026-contact)](#contact)

`info.contact` **SHOULD** name the owning team and give a `url` and an `email`, so that a consumer who sees an unexpected event knows whom to ask.

---

## [Operation Summary (api-peak:async5:2026-operation-summary)](#operation-summary)

Every operation **MUST** have a `summary` that starts with a capital letter and is at most 75 characters long. A longer explanation belongs in `description`.

---

## [Operation Naming (api-peak:async6:2026-operation-naming)](#operation-naming)

Operation identifiers **SHOULD** be camelCase and start with the action they describe: `send` or `receive`, for example `sendOrderCreated`.

---

## [One Message per Operation (api-peak:async7:2026-one-message-per-operation)](#one-message-per-operation)

An operation **MUST** reference exactly one message. A channel may carry several message types, but each one gets its own operation, so that bindings, documentation, mocks and contract tests apply to one event type at a time.

---

## [Messages from Own Channel (api-peak:async15:2026-own-channel-messages)](#own-channel-messages)

An operation **MUST** only reference messages defined on its own channel (`$ref: '#/channels/<its channel>/messages/...'`). A message borrowed from another channel would be published on a topic whose contract does not describe it, so mocks, contract tests and the broker policy would all look at the wrong topic.

---

## [Message Metadata (api-peak:async8:2026-message-metadata)](#message-metadata)

Every message **MUST** have a `name` in PascalCase (the event type, for example `OrderCreated`), a human readable `title`, a `contentType` and a `payload`.

---

## [Message Examples (api-peak:async9:2026-message-examples)](#message-examples)

Every message **MUST** have at least one example. Examples drive the mock events and are the first thing a consumer reads.

---

## [JSON Payloads (api-peak:async10:2026-json-payloads)](#json-payloads)

Payloads **MUST** be JSON (`application/json`), described with JSON Schema, see [JSON](index.md#json-api-peakgeneral112025-json). Correlation and tracing data, such as a correlation id, **SHOULD** travel in message headers, not in the payload.

---

## [Property Naming (api-peak:async11:2026-property-naming)](#property-naming)

Payload property names **MUST** be camelCase, for example `orderId` or `createdAt`.

---

## [Schema Naming (api-peak:async12:2026-schema-naming)](#schema-naming)

Names of reusable schemas under `components.schemas` **SHOULD** be PascalCase, for example `OrderCreatedPayload`.

---

## [Open Payload Schemas (api-peak:async13:2026-open-payloads)](#open-payloads)

Payload schemas **MUST NOT** set `additionalProperties: false`. Producers add optional fields over time; a closed schema would turn every such addition into a breaking change for consumers. Consumers **MUST** ignore fields they do not know, see [Robustness](index.md#robustness-api-peakgeneral72025-robustness).

---

## [Compatibility (api-peak:async14:2026-compatibility)](#compatibility)

A change to a published API **MUST NOT** break its existing consumers. For an event the API sends, these are breaking:

- changing or removing a topic, an operation or a channel, or flipping an operation's action;
- changing the MQTT `qos` or `retain` of an operation;
- a payload that consumers built on the previous schema cannot read: removing a field, changing a field's type, or narrowing an allowed value.

Adding an optional or required field to an event is not breaking: consumers ignore what they do not know (see [Open Payload Schemas](#open-payload-schemas-api-peakasync132026-open-payloads)).

A breaking change **MUST** be published as a new MAJOR version on a new topic version (for example `orders/v2/...` on MQTT, `orders.order-created.v2` on Kafka), next to the old one, until its consumers have moved.

The PR gate checks the structure with `@asyncapi/diff` and every payload against the schema registry. The registry rule follows who reads the payload: **FORWARD** for events the API sends, **BACKWARD** for messages it receives.

---
