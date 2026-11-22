# General API Guidelines
## [API First Approach (api-peak:general1:2025-api-first)](#api-first)

Everyone **SHOULD** follow the **API First** principle. The API First principle is an extension of the **design-first** principle. Therefore, API development **SHOULD** always start with the API design, without any preliminary coding activity. The API design (e.g. description, schema) is the **source of truth**, not the API implementation. The API implementation **MUST** always conform to the specific API design, which represents the contract between the API and its consumer.

---

---

## [Language (api-peak:general2:2025-language)](#language)

TBD.

---

## [Terminology (api-peak:general3:2025-terminology)](#terminology)

- **API Specification** - refers to a specification format, such as OpenAPI or AsyncAPI, but not to a document created using such a specification.

- **API Document/API Description/API Description Document** - refers to a document describing an API design using a specification such as OpenAPI.

- **Schema** - refers to a description of a data model. It is usually created using a specification such as JSON-Schema, Avro Schema, or Protobuf.

- **API Design** - refers to the formal description of an API. It does not have to, but may, refer to the API Description Document.

---

## [New and Existing APIs (api-peak:general4:2025-new-existing-APIs)](#new-vs-existing)

For all newly created APIs, all [API Guidelines rules](/) **MUST** be met within the specified scope (MUST/SHOULD/MAY)<!-- and [async API design rules]()-->.

For already existing APIs, the [API Guidelines rules](/) **SHOULD** be met.

## [Semver (api-peak:general5:2025-semver)](#semver)

The API **MUST** use Semantic Versioning (SemVer) in the MAJOR.MINOR.PATCH format as the only allowed versioning scheme.

### Version Components

- **MAJOR**: Incremented when introducing backward-incompatible changes.
- **MINOR**: Incremented when adding new functionality that is _potentially_ backward compatible.
- **PATCH**: Incremented when making backward-compatible bug fixes.

> **Potential backward compatibility:** we speak of **potential** backward compatibility because it can happen that backward-compatible changes turn out not to be, e.g. due to strict client constraints such as message size. For this reason, hard backward compatibility cannot be guaranteed.

---

## [Contract (api-peak:general6:2025-contract)](#api-contract)

An approved **API design**, represented by its **API document** or schema, **MUST** constitute the contract between API stakeholders, "providers", and consumers. An update to the corresponding contract (**API design**) **MUST** be implemented in its description and approved before any changes are made to the API implementation.

<!-- 
---

### Immutability

Once agreed with stakeholders, the contract **MUST** be published in the **API registry** to make it (this version) permanent. The API registry acts as a central place to store and access all published APIs.-->

---

## [Robustness (api-peak:general7:2025-robustness)](#robustness)

Every API implementation and every API consumer **MUST** follow **Postel's Law**:

> Be conservative in what you send, be liberal in what you accept.
> 
> – [John Postel](https://en.wikipedia.org/wiki/Robustness_principle)

This means sending the necessary minimum and being as tolerant as possible when using another service (the [tolerant reader](https://martinfowler.com/bliki/TolerantReader.html)).

---

## [Version Control System (api-peak:general8:2025-version-control)](#version-control)

Every API design **MUST** be stored in a Version Control System (e.g. Bitbucket, GitHub). Where possible, the API design **SHOULD** be stored in the same repository as the API implementation. In the case of strict security policies regarding access to the repository containing the API implementation, the API contract **SHOULD** be made available for stakeholders to review elsewhere.

---

## [Minimal API Surface (api-peak:general9:2025-yagni)](#yagni)

Every API design **MUST** strive for a minimal API surface without sacrificing product requirements. The API design **SHOULD NOT** include unnecessary resources, relationships, actions, or data. The API design **SHOULD NOT** add functionality until it is deemed necessary (the [YAGNI](https://en.wikipedia.org/wiki/You_aren%27t_gonna_need_it) principle).

---

## [Rules of Extensibility (api-peak:general10:2025-rules-of-extension)](#rules-of-extension)

Every modification of an existing API **MUST** avoid introducing breaking changes and **MUST** maintain backward compatibility. Where there is a need to break backward compatibility, the API **MUST** also change its **major** version.

In particular, every change to the API **MUST** follow these Rules of Extensibility:

- You **MUST NOT** remove anything (related: [Minimal Surface Principle](https://en.wikipedia.org/wiki/YAGNI), [Robustness Principle](https://en.wikipedia.org/wiki/Robustness_principle))
- You **MUST NOT** change processing rules
- You **MUST NOT** make optional things required
- Anything you add **MUST** be optional (related: [Robustness Principle](https://en.wikipedia.org/wiki/Robustness_principle))

> NOTE: These rules also cover renaming and changing identifiers (URIs). Names and identifiers should be stable over time, including their semantics.

---

## [JSON (api-peak:general11:2025-json)](#json)

Every JSON-based message **MUST** conform to the following rules:

- All JSON field names **MUST** follow the [Naming Conventions]()
- Field names **MUST** consist of alphanumeric ASCII characters, underscore (_), or dollar sign ($)
- Boolean fields **MUST NOT** have a `null` value
- Fields with a `null` value **SHOULD** be omitted
- Empty arrays and objects **MUST NOT** be `null` (use `[]` or `{}` instead)
- Field names for arrays **SHOULD** be plural (e.g. `"orders": []`)

<!--
### Validation

All APIs **MUST** validate their request/response payloads using a JSON Schema for the defined structure before publishing the API Contract.

The published JSON schema corresponding to the expected request and response body payloads **SHOULD** be updated as the API evolves.
-->

---

## [Single Source of Truth (api-peak:general12:2025-single-source-of-truth)](#single-source-of-truth)
<!--
Azure API Center is the primary platform supporting the API-first approach. Azure API Center **MUST** be used when designing an API.

Every API description **MUST** be stored in Azure API Center within the API Peak team. -->

Interface definition schema files, such as:

- OpenAPI Specification (OAS)/Swagger
- GraphQL Schema Definition Language (SDL)
- Web Service Description Language (WSDL)
- Avro Schema

and similar, located in the project repository, **MUST** be the single source of truth for the API definition.

<!-- Azure API Center **SHOULD** be fed directly from the project repository with a design file, such as

NOTE: Azure API Center supports the API-first approach in many ways:
For example, it validates the correctness of the API description and automatically generates API documentation, making it easier for stakeholders to discuss. (No more exchanging emails with the API description between stakeholders) -->

# Async API Guidelines

The API Peak async guidelines define the standards for event-driven APIs described with AsyncAPI. They apply together with the General API Guidelines above. Every rule below is checked automatically: its identifier is the rule name in the linter ruleset (`asyncapi-ruleset.yaml` in the governance repository), and every finding links back to its section here.

---

## [AsyncAPI Specification (api-peak:async1:2026-asyncapi)](#asyncapi-specification)

An event-driven API **MUST** be described using the AsyncAPI specification, version **3.x**. The AsyncAPI document is the contract between the producer and its consumers (see [Contract](#contract-api-peakgeneral62025-contract)).

---

## [API Title (api-peak:async2:2026-api-title)](#api-title)

`info.title` **MUST** be written in Title Case and **MUST** end with the word `API`, for example `Order Events API`.

---

## [API Version (api-peak:async3:2026-api-version)](#api-version)

`info.version` **MUST** follow Semantic Versioning (`MAJOR.MINOR.PATCH`), see [Semver](#semver-api-peakgeneral52025-semver). A breaking change to any channel, operation or payload requires a new MAJOR version.

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

Payloads **MUST** be JSON (`application/json`), described with JSON Schema, see [JSON](#json-api-peakgeneral112025-json). Correlation and tracing data, such as a correlation id, **SHOULD** travel in message headers, not in the payload.

---

## [Property Naming (api-peak:async11:2026-property-naming)](#property-naming)

Payload property names **MUST** be camelCase, for example `orderId` or `createdAt`.

---

## [Schema Naming (api-peak:async12:2026-schema-naming)](#schema-naming)

Names of reusable schemas under `components.schemas` **SHOULD** be PascalCase, for example `OrderCreatedPayload`.

---

## [Open Payload Schemas (api-peak:async13:2026-open-payloads)](#open-payloads)

Payload schemas **MUST NOT** set `additionalProperties: false`. Producers add optional fields over time; a closed schema would turn every such addition into a breaking change for consumers. Consumers **MUST** ignore fields they do not know, see [Robustness](#robustness-api-peakgeneral72025-robustness).

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

# MQTT API Guidelines

These rules apply to APIs whose servers use MQTT.

---

## [Topic Naming (api-peak:mqtt1:2026-topic-naming)](#topic-naming)

Channel addresses (MQTT topics) **MUST** consist of lowercase levels made of letters, digits and hyphens, separated by `/`. A level **MAY** be a parameter written as `{camelCase}`. Topics **MUST NOT** start or end with `/`, **MUST NOT** contain the wildcards `+` or `#`, and **MUST NOT** start with `$` (reserved for broker system topics).

Example: `orders/v1/{orderId}/created`.

---

## [Topic Versioning (api-peak:mqtt2:2026-topic-version)](#topic-version)

Every topic **MUST** contain a major version level `v{MAJOR}`, for example `orders/v1/...`. A breaking change publishes to a new version level, so that existing subscribers keep receiving the events they understand.

---

## [Quality of Service (api-peak:mqtt3:2026-qos)](#qos)

Every operation **MUST** declare its MQTT quality of service in `bindings.mqtt.qos`. Consumers size their deduplication and retry logic from it.

---

## [One Event Type per Topic (api-peak:mqtt6:2026-one-event-type-per-topic)](#one-event-type-per-topic)

Every channel (topic) **MUST** carry exactly one message type. MQTT has no standard header for the event type, so subscribers choose the events they want by topic (for example `orders/v1/+/paid`), and a contract test listening on a topic knows which schema applies. Related event types share a topic prefix instead: `orders/v1/{orderId}/created`, `orders/v1/{orderId}/paid`.

---

## [Retained Messages (api-peak:mqtt4:2026-retain)](#retain)

Every operation **SHOULD** declare `bindings.mqtt.retain`. Events (something happened) are not retained; state (the latest value of something) may be.

---

## [Secure Transport (api-peak:mqtt5:2026-secure-transport)](#secure-transport)

Servers **MUST** use `secure-mqtt` (MQTT over TLS). Plain `mqtt` is allowed only for a local development broker (`localhost`, `127.0.0.1` or the demo's `mosquitto`).

---

# Kafka API Guidelines

These rules apply to APIs whose servers use Kafka.

---

## [Topic Naming (api-peak:kafka1:2026-topic-naming)](#kafka-topic-naming)

Channel addresses (Kafka topics) **MUST** be named `<domain>.<event-name>.v<MAJOR>`: lowercase words made of letters, digits and hyphens, separated by `.`, ending in the major version. Topics **MUST NOT** contain parameters: Kafka has no topic hierarchy, so the entity id goes into the message key instead (see [Message Key](#kafka-message-key)).

Example: `orders.order-created.v1`. A breaking change publishes to `orders.order-created.v2`, next to the old topic.

---

## [One Event Type per Topic (api-peak:kafka2:2026-one-event-type-per-topic)](#kafka-one-event-type-per-topic)

Every channel (topic) **MUST** carry exactly one message type. The schema registry keys a payload schema by topic, so one topic has one schema and one compatibility rule, and a contract test listening on a topic knows which schema applies.

---

## [Message Key (api-peak:kafka3:2026-message-key)](#kafka-message-key)

Every message **MUST** declare its key in `bindings.kafka.key`. Kafka keeps order only within a partition, and the key picks the partition: keying every event of an entity by its id (for example the order id) delivers that entity's events in order.

---

## [Partitions (api-peak:kafka4:2026-partitions)](#kafka-partitions)

Every channel **MUST** declare `bindings.kafka.partitions`. The partition count limits how many consumers of one group read in parallel, and the broker policy creates the topic from it. The count **MAY** grow later; it **MUST NOT** shrink, which Kafka does not allow.

---

## [Retention (api-peak:kafka5:2026-retention)](#kafka-retention)

Every channel **SHOULD** declare its retention in `bindings.kafka.topicConfiguration` (`retention.ms`). Consumers need to know how far back they can replay events after an outage.

---

## [Secure Transport (api-peak:kafka6:2026-secure-transport)](#kafka-secure-transport)

Servers **MUST** use `kafka-secure` (Kafka over TLS). Plain `kafka` is allowed only for a local development broker (`localhost`, `127.0.0.1` or the demo's `kafka`).
