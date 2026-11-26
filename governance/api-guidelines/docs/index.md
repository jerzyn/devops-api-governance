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
Interface definition schema files, such as:

- OpenAPI Specification (OAS)/Swagger
- GraphQL Schema Definition Language (SDL)
- Web Service Description Language (WSDL)
- Avro Schema

and similar, located in the project repository, **MUST** be the single source of truth for the API definition.
