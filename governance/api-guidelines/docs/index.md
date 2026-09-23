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

# REST API Guidelines

The API Peak REST guidelines define the standards and guidance for building REST API interfaces at API Peak. These guidelines must be followed together with the API Peak General API Design Guidelines.

## [OpenAPI Specification (api-peak:rest1:2025-openapi)](#open-api-specification)

Every API **MUST** be described using the OpenAPI description format. The OpenAPI format used **MUST** conform to the [OpenAPI Specification (formerly known as the Swagger Specification), version 3.x.y](https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.1.1.md). Where possible, the API description format **SHOULD** conform to the 3.1.x specification, due to its full compatibility with the JSON-Schema format.

### `info.version` in OpenAPI (api-peak:rest2:2025-openapi-version)

The `info.version` element in the OpenAPI document **MUST** specify the version of the API document. This version is not the same as the API version.

---

## [API Design Maturity (api-peak:rest3:2025-design-maturity-wadmm)](#maturity-wadmm)

> How to design an API

Every API design **MUST** be resource-oriented ([Level 2 of the Web API Design Maturity Model](http://amundsen.com/talks/2016-11-apistrat-wadm/2016-11-apistrat-wadm.pdf)). This means the API design **MUST** be based on Web-style resources, the relationships between these resources, and the actions they may offer.

The API design **SHOULD** be task-oriented ([Level 3 of the Web API Design Maturity Model](http://amundsen.com/talks/2016-11-apistrat-wadm/2016-11-apistrat-wadm.pdf)).

---

## [API Design Implementation Maturity (api-peak:rest4:2025-design-maturity-rmm)](#maturity-rmm)

Every API design implementation using the HTTP protocol **MUST** use the appropriate HTTP request method ([Level 2 of the Richardson Maturity Model](https://martinfowler.com/articles/richardsonMaturityModel.html#level2)) to perform the action offered by the resource.

The API design implementation **SHOULD** include hypermedia controls (HATEOAS) ([Level 3 of the Richardson Maturity Model](https://martinfowler.com/articles/richardsonMaturityModel.html#level3)).

<!-- 
---

## [Contract testing](#contract-testing)

Every REST API implementation **MUST** be tested against its contract, i.e. the API design in OpenAPI format.
-->
---

## [Naming Conventions](#naming-conventions)

The following naming conventions apply to the API description format.

### [General Naming Rules (api-peak:rest5:2025-general-naming-conventions)](#general-naming-conventions)

Every identifier **MUST** be written in lowercase.

An identifier **SHOULD NOT** contain business acronyms.

The `camelCase` convention **MUST** be used to separate compound words (e.g. `itemIdentifier`).  

### [URI (api-peak:rest6:2025-uri-naming-conventions)](#uri-naming-conventions)  

Every URI **MUST** follow the General Rules, except for the `camelCase` convention. Instead, a hyphen (-) **MUST** be used to separate compound words (the `kebab-case` convention). In addition, a URI **MUST NOT** end with a slash (/). <!-- what about examples where the identifier contains a /? -->

Plural nouns **SHOULD** be used in URIs to identify collections of data resources (e.g. `/orders`, `/products`).

A single resource within a resource collection **MAY** exist directly under the collection's URI (e.g. `/orders/{order_id}`).

<!-- how to address the problem of many very long identifiers, the URI limit is 1024 characters -->

#### Example

A correctly formed URI:  

```text
/system-orders/1234/author
```

### [Query Parameters and Path Fragments (api-peak:rest7:2025-paths-naming-conventions)](#parameters-paths-naming-conventions)  

Every URI query parameter or fragment **MUST** follow the General Rules. In addition, they **MUST NOT** collide with reserved query parameter names, e.g. `offset` for pagination, or parameters reserved by whatever is in use.

<!-- clarify which parameters are reserved; are they always reserved, or just as a convention/best practice -->

#### [URI Template Variables (api-peak:rest8:2025-path-params-naming-conventions)](#path-params-naming-conventions)

In addition to the General Naming Rules, URI template variable names **MUST** conform to [RFC6570](https://datatracker.ietf.org/doc/html/rfc6570#section-2.3). This means variable names may consist only of the symbols `ALPHA / DIGIT / "_" / pct-encoded`.

<!-- When is it possible for URI templates to be pct-encoded? -->

> **NOTE:** According to RFC6570, the hyphen character (-) is NOT an allowed character for URI template variable names.  

#### Example  

A correctly formed URI template variable:  

```text
/system-orders/{orderId}/author
```

### [Representation Field Format (api-peak:rest9:2025-representation-format-naming-conventions)](#representation-format-naming-conventions)

Every representation format field **MUST** conform to the General Naming Rules.

#### Example
A correctly formed resource representation:  

```json
{
  "_links": {
    "self": {
      "href": "/orders/1234"
    },
    "author": {
      "href": "/users/john"
    }
  },
  "orderNumber": 1234,
  "itemCount": 42,
  "status": "pending"
}
```
<!--
### [Relation Type Identifier](#relation-type-naming-conventions)

Every custom relation identifier **MUST** be written in lowercase, with words separated by a hyphen (-).  

#### Example

A correctly formed resource representation with a custom fulfillment-provider relation:  

```json
{
  "_links": {
    "fulfillment-provider": {
      "href": "/users/natalie"
    }
  }
}
```
-->
### [HTTP Headers (api-peak:rest10:2025-headers-naming-conventions)](#headers-naming-conventions)

Every HTTP header **SHOULD** use the `Hyphenated-Pascal-Case` convention. A custom HTTP header **SHOULD NOT** start with `X-` (per [RFC6648](https://datatracker.ietf.org/doc/html/rfc6648)).

#### Example

```text
Order-Metadata-Header: 42
```

---

## [API Description](#api-description)

### [API Name (api-peak:rest11:2025-api-naming)](#api-naming) 

Every API name in the API description document **MUST** be written in **Title Case**, meaning every word **MUST** start with a capital letter. In addition, every API name **MUST** end with the word `API`. The API title **SHOULD NOT** contain business acronyms or abbreviations, e.g. `Grp Ins API` or `Clm Sttlmt API`.

#### Example

```yaml
openapi: '3.1.0'
info:
  version: '1.0.0'
  title: 'Customer Orders API'
```

### [Resource Name (api-peak:rest12:2025-resource-name)](#resource-name)

Every resource (endpoint) **MUST** have a name (defined in the `summary` field). The resource name **MUST** be written in **Title Case**, with words separated by a space. The resource name **SHOULD NOT** contain business acronyms or abbreviations, e.g. `Grp List` or `Ins List`.

#### Example

```yaml
/orders:
  summary: List of Orders
```

### [Operation Name (api-peak:rest13:2025-operation-name)](#operation-name)

Every operation (action) **MUST** have a name (defined in the `summary` field). The action name **MUST** be written in **Title Case**, with words separated by a space. The operation name **SHOULD NOT** contain business acronyms or abbreviations, e.g. `Update Grp List` or `Delete Ins`.

#### Example

```yaml
get:
  summary: Retrieve List of Orders
```

### [Operation Description (api-peak:rest14:2025-operation-description)](#operation-description)

Every operation (action) **SHOULD** have a description (defined in the `description` field). Every description **SHOULD** be at least 30 characters long. The description **MAY** be in Markdown format.

#### Example

```yaml
get:
  summary: Retrieve List of Orders
  description: Retrieve a list of all orders in the store. You can filter orders by date and customer.

```

---
<!-- to verify, add example -->
## [URI Structure (api-peak:rest15:2025-uri-structure)](#uri-structure)

The URI is used to express the identity of a resource. The URI is an identifier and **MUST NOT** convey any other information.

At API Peak, URIs are subject to the naming conventions described above.

To learn more about this topic, refer to [RFC 7320: URI Design and Ownership](https://tools.ietf.org/html/rfc7320).
<!-- up to here -->
---

## [HTTP (api-peak:rest16:2025-http)](#http)

Every API **MUST** support at least [HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112) and **MUST** follow its semantics. <!-- The API **MAY** support HTTP/2 or HTTP/3. (add links) -->

### [HTTPS (api-peak:rest17:2025-https)](#https)

Every API **MUST** require secure connections using [TLS version 1.2 or later](https://datatracker.ietf.org/doc/html/rfc5246). It **MAY** use [TLS 1.3](https://datatracker.ietf.org/doc/html/rfc8446). This means that an API using the HTTP protocol **MUST** use HTTPS.

Any requests without TLS **SHOULD** be ignored. In HTTP environments where this is not possible, a request without TLS **SHOULD** result in a `403 Forbidden` response.

---

## [Separation of Concerns (api-peak:rest18:2025-separation-of-concerns)](#separation-of-concerns)

Every API using HTTP **MUST** strictly follow the separation of concerns in the HTTP message:

I. The *resource identifier (URI)* **SHOULD** be used solely to indicate identity <!-- eventually MUST -->
II. The *HTTP request method* **MUST** be used to communicate the semantics of the action (intent and safety)
III. The *HTTP response status code* **MUST** be used to convey information about the outcome of the attempt to understand and fulfill the request
IV. The *HTTP message body* **MUST** be used to transmit the message content
V. *HTTP message headers* **MUST** be used to convey metadata about the message and its content
VI. The *URI query parameter* **SHOULD NOT** be used to convey metadata

### Examples

These can be found on the [best practices page, in the "Separation of Concerns" section](/best-practices#separation-of-concerns).

---

## [Request Methods (api-peak:rest19:2025-request-methods)](#request-methods)

Every API **MUST** use the correct [HTTP methods](https://github.com/for-GET/know-your-http-well/blob/master/methods.md) for each operation.

Every API user (_provider_, _consumer_, etc.) **MUST** understand the semantics of the HTTP method they use.

Everyone **MUST** be familiar with the semantics of the ["common" HTTP request methods](https://github.com/for-GET/know-your-http-well/blob/master/methods.md#common): **DELETE**, **GET**, **HEAD**, **PUT**, **POST**, and [**PATCH**](https://tools.ietf.org/html/rfc5789#section-2). In addition, everyone **MUST** know which methods are [**safe**](/rest#safe-methods), [**idempotent**](/rest#idempotency), and [**cacheable**](/rest#cacheable-methods).

### [Safe Methods](#safe-methods)

Per the HTTP specification, the **GET** and **HEAD** methods should be used solely to retrieve resource representations – they do not update/delete resources on the server. Both methods are considered "safe". This allows user agents to represent other methods, such as POST, PUT, and DELETE, specially, so the user is aware of a potentially unsafe action – these may update/delete a resource on the server and should therefore be used with caution.

### [Idempotent Methods](#idempotency)

The term idempotency describes an operation that produces the same results whether performed once or multiple times. This is a beneficial property in many situations, since it means a transaction can be repeated or retried as many times as necessary without causing unintended effects. In the HTTP specification, the **GET**, **HEAD**, **PUT**, and **DELETE** methods are considered idempotent. The other methods, **OPTIONS** and **TRACE**, **SHOULD NOT** have side effects, so both are also inherently idempotent. HTTP methods **MUST NOT** be implemented with idempotency different from what is defined by default.

### [Cacheable Methods](#cacheable-methods)

Request methods are considered _cacheable_ if it is possible and useful to respond to the current client request with a stored response from a previous request. **GET** and **HEAD** are defined as cacheable.

#### Example 1

```text
GET /user/new Description: Creates a new user
```

Using GET for unsafe and non-idempotent operations is **not allowed**.

#### Example 2

```text
POST /status Description: Updates the status of a user approval request (to "Approved" or "Rejected")
```

Using the POST method to update status is **not allowed** (PATCH should be used instead).

#### Example 3

```text
PUT /user Description: Creates a new user
```

Using the PUT method to create a new resource is ***not allowed*** (POST should be used instead).

#### Example 4

```text
PUT: /user Description: Updates some details of a user
```

Using the PUT method for a partial update is **not allowed** (PATCH should be used instead).

---

## [Response Status Codes (api-peak:rest20:2025-status-codes)](#status-codes)

Every API **MUST** use the appropriate [HTTP status codes](https://github.com/for-GET/know-your-http-well/blob/master/status-codes.md) to communicate the outcome of a request operation.

Every API designer, implementer, and user **MUST** understand the semantics of the HTTP status code they use.
Everyone **SHOULD** be familiar with the semantics of the [_common_ HTTP status codes](https://github.com/for-GET/know-your-http-well/blob/master/status-codes.md#common).

### [Use 4xx or 5xx Codes to Communicate Errors (api-peak:rest21:2025-error-codes)](#error-codes)

The `4xx` range covers errors on the API consumer/client side, while the `5xx` range covers errors in the infrastructure service or API implementation.

Request:

```text
GET /orders/1234 HTTP/1.1
...
```

resulting in a `200 OK` response, when the requested resource (identified by the request URI) was not found:

```text
HTTP/1.1 200 OK
Content-Type: application/json
...

{
    "code": "NOT_FOUND_ERR_CODE",
    "message": "Order 1234 wasn't found"
}
```

is ***not allowed***.

Instead, the following should be returned:

```text
HTTP/1.1 404 Not Found
...
```

### Recommended Reading

[How to think about HTTP status codes](https://www.mnot.net/blog/2017/05/11/status_codes)

---

## [Message Format](#message-format)

### [Error Response Format (api-peak:rest22:2025-problem-detail)](#problem-detail)

The `application/problem+json` (Problem Detail) format **MUST** be used to communicate error details.

Problem Detail is intended for use with 4xx and 5xx HTTP status codes. Problem Detail **MUST NOT** be used with 2xx status code responses.

Every Problem Detail response **MUST** include the `title` and `detail` fields. The `title` value **SHOULD NOT** change with every occurrence of the problem, except for localization purposes (e.g. using proactive content negotiation).

#### Example

```json
{
  "title": "Authentication required",
  "detail": "Missing authentication credentials for the Greeting resource."
}
```

> NOTE: The `title` and `detail` fields **SHOULD NOT** be parsed to determine the nature of the error. The `type` field **MUST** be used instead.

#### Optional Fields

Every Problem Detail response should have a `type` field with an error identifier. It **MAY** also have an `instance` field with the URI of the affected resource. If a Problem Detail response includes a `status` field, it **MUST** have the same value as the response's HTTP status code.

```json
{
  "type": "https://api-peak.com/problems/scv/unauthorized",
  "title": "Authentication required",
  "detail": "Missing authentication credentials for the Greeting resource.",
  "instance": "/greeting",
  "status": 401
}
```

> NOTE: The `type` field is an identifier and, as such, **MAY** be used to denote additional error codes. Keep in mind that the identifier should be a URI.

#### Additional Fields

If necessary, Problem Detail **MAY** include additional fields; see [RFC9457](https://www.rfc-editor.org/rfc/rfc9457) for details.

### [Request Message Format (api-peak:rest23:2025-message-json)](#message-json)

Request messages with a body **MUST** support the `application/json` (JSON) format.

## [Content Negotiation (api-peak:rest24:2025-content-negotiation)](#content-negotiation)

Every API **MUST** implement, and every API Consumer **MUST** use, [HTTP content negotiation](https://tools.ietf.org/html/rfc7231#section-3.4) **when a resource representation is requested**.

> NOTE: Content negotiation plays a key role in API evolution, change management, and versioning.

#### Example

A client is programmed to understand the semantics of the message format `application/vnd.example.resource+json; version=2`. The client requests a representation of the `/greeting` resource in the desired media type (including its version) from the server:

```text
GET /greeting HTTP/1.1
Accept: application/vnd.example.resource+json; version=2
...
```

The server may only have a newer version of the requested media type available, `version=2.1.3`. However, since the newer version is backward compatible with the requested `version=2` (see: [Changes and Versioning](./#changing-versioning)), it can fulfill the request and responds:

```text
HTTP/1.1 200 OK
Content-Type: application/vnd.example.resource+json; version=2.1.3
...
```

> NOTE: A server that does not have the requested media type representation available **MUST** respond with the HTTP status code **406 Not Acceptable**.

> NOTE: A server **MAY** have multiple options available and **MAY** respond with **300 Multiple Choices**. In this case, the client **SHOULD** choose from the options presented.

More on content negotiation can be found on the [MDN Content negotiation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Content_negotiation) page.

---

## [Data Types](#data-formats)

### [Date and Time Format (api-peak:rest25:2025-date-time-format)](#date-time-format)

Date and time **MUST** always conform to the [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) format, e.g.: `2017-06-21T14:07:17Z` (date and time) or `2017-06-21` (date)<!--, **MUST** use UTC (no time zone offsets) - we still need to decide which time zone to use. Is it Polish time, UTC, etc. Keep in mind that the time zone changes depending on daylight saving time (winter is our nominal UTC+1 zone, summer is UTC+2)-->.

### [Duration Format (api-peak:rest26:2025-duration-format)](#duration-format)

The duration format **MUST** conform to the [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) standard, e.g.: `P3Y6M4DT12H30M5S` (three years, six months, four days, twelve hours, thirty minutes, and five seconds).

### [Time Interval Format (api-peak:rest27:2025-timeframe-format)](#timeframe-format)

The time interval format **MUST** conform to the [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) standard, e.g.: `2007-03-01T13:00:00Z/2008-05-11T15:30:00Z`.

### [Standard Timestamps (api-peak:rest28:2025-timestamps)](#timestamps)

Where possible, the resource representation **SHOULD** include standard timestamps:

- `createdAt`
- `updatedAt`
- `finishedAt`

#### Example

```json
{
    "createdAt": "2017-01-01T12:00:00Z",
    "updatedAt": "2017-01-01T13:00:00Z",

    ...
}
```

### [Language Code Format (api-peak:rest29:2025-language-codes)](#language-codes)

Language codes **MUST** conform to [ISO 639](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes), e.g.: `pl` for Polish.

### [Country Code Format (api-peak:rest30:2025-country-codes)](#country-codes)

Country codes **MUST** conform to [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2), e.g.: `PL` for Poland.

### [Currency Format (api-peak:rest31:2025-currency-codes)](#currency-codes)

Currency codes **MUST** conform to [ISO 4217](https://en.wikipedia.org/wiki/ISO_4217), e.g.: `PLN` for the Polish złoty.

---

## [Pagination (api-peak:rest32:2025-pagination)](#pagination)

A collection resource **SHOULD** provide `first`, `last`, `next`, and `prev` links for navigating within the collection.

#### Example

An order collection using collection navigation links and the `offset` and `limit` query parameters:

```json
{
  "_links": {
    "self": { "href": "/orders?offset=100&limit=10" },
    "prev": { "href": "/orders?offset=90&limit=10" },
    "next": { "href": "/orders?offset=110&limit=10" },
    "first": { "href": "/orders?limit=10" },
    "last": { "href": "/orders?offset=900&limit=10" }
  },
  "totalCount": 910,
  "_embedded": {
    "order": [
      { ... },
      { ... },

      ... 
    ]
  }
}
```

---

## [Batch Operations (Batch processing)](#batch-processing)

### [Processing Similar Resources (api-peak:rest33:2025-collections)](#collections)

An operation that must process several related resources in a batch **SHOULD** use a collection resource with the appropriate HTTP method. When processing existing resources, the request message body **MUST** include the URLs of the respective resources being processed.

#### Example

Creating multiple orders at once

```json
POST /orders
Content-Type: application/json

{
  "orders": [
    {
      "itemCount": 42
    },
    {
      "itemCount": 2
    }
  ]
}
```

Updating multiple orders at once

```json
PATCH /orders
Content-Type: application/json

{
  "orders": [
    {
      "_links": {
        "self": { "href": "/order/1"}
      },
      "itemCount": 42
    },
    {
      "_links": {
        "self": { "href": "/order/2"}
      },      
      "itemCount": 2
    }
  ]
}
```

### [Batch Operation Results (api-peak:rest34:2025-batch-operations-results)](#batch-operations-results)

Every batch operation **MUST** be atomic and treated the same as any other operation.

> The server must implement batch requests as atomic. If a request is to create ten addresses, the server should create all ten addresses before returning a success response code. The server should not partially commit changes in the event of failures.

### [DO NOT USE "POST Tunneling" (api-peak:rest35:2025-post-tunneling)](#post-tunneling)

Every API **MUST** avoid tunneling multiple HTTP requests within a single POST request. Instead, a dedicated application resource should be provided for processing batch requests.

### [Non-Atomic Batch Operations (api-peak:rest36:2025-non-atomic-batch-operations)](#non-atomic-batch-operations)

Non-atomic batch operations are strongly discouraged, as they impose additional burden and introduce confusion for the client. They are hard to consume, debug, maintain, and evolve over the long term.

It is recommended to split a non-atomic operation into several atomic operations. The cost of a few extra calls will be offset by a cleaner design, greater clarity, and easier maintenance.

However, if such an operation must be provided, a non-atomic batch operation **MUST** meet the following guidelines:

- A non-atomic batch operation **MUST** return a success status code (e.g. `200 OK`) only when every sub-operation has succeeded.
- If any sub-operation fails, the entire non-atomic batch operation **MUST** return the appropriate `4xx` or `5xx` status code.
- In the event of an error, the response **MUST** include problem details for every sub-operation that failed.
- The client **MUST** be aware that the operation is non-atomic and that even if the operation as a whole failed, some sub-operations may have been processed successfully. This information **MUST** be included in the API response.

#### Example

A non-atomic request to create four orders:

```json
POST /orders
Content-Type: application/json

{
  "orders": [
    {
      "itemCount": 42
    },
    {
      "itemCount": -100
    },        
    {
      "itemCount": 42
    },
    {
      "itemCount": 1.3232
    }
  ]
}
```

Error response:
```json
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type": "https://example.net/partial_operation_failure",
  "title": "Partial Failure",
  "detail": "Some orders couldn't be created, other orders were created.",

  "errors": [
    {
      "type": "https://example.net/invalid-params",
      "instance": "/orders/1",
      "title": "Invalid Parameter",
      "detail": "itemCount must be a positive integer",
      "status": 400
    },
    {
      "type": "https://example.net/invalid-params",
      "instance": "/orders/3",
      "title": "Invalid Parameter",
      "detail": "itemCount must be a positive integer",
      "status": 400
    }
  ],

  "processed": ...
}
```

The `processed` field should contain the result of the processed sub-operations, as if they had been returned in a `200 OK` response.

---

## [Search Queries (api-peak:rest37:2025-filtering)](#filtering)

A search (filtering) operation on a collection resource **SHOULD** be defined as safe, idempotent, and cacheable; therefore the **GET** HTTP method should be used.  

Every search parameter **SHOULD** be passed as a query parameter. Where search parameters are mutually exclusive or require the presence of another parameter, an explanation **MUST** be part of the operation description. 

When advantageous (e.g. one of the filtering parameters is used more often than others), a separate resource **SHOULD** be provided for the specific query. In that case, the key search parameter **MAY** be passed as a path variable.

<!-- Add what to do in case of a large number of query params (the URI limit is 1024 characters) -->

#### Example  

An order collection can be filtered by the id of an article it contains, or by the id of an article's manufacturer. These two parameters are mutually exclusive and cannot be used together. The API description for such a design should look as follows:  

```yaml
paths:
  /orders:
    x-summary: Collection of Orders

    get:
      summary: Retrieve or Search in the Collection of Orders
      description: | 

        This operation allows to retrieve a filtered list of orders based on multiple criteria:

        1. **Filter Orders by Article Id**
        2. **Filter Orders by Manufacturer Id**

      parameters:
        - name: article_id
          in: query
          description: | 
            Article Id. Denotes the id of an article that must be in the order.

            **Mutually exclusive** with `manufacturer_id`.

          required: false
          type: string
          x-example: article_id_1

        - name: manufacturer_id
          in: query
          description: |
            Manufacturer Id. Denotes an id of a manufacturer of an article that must be in the order.

            **Mutually exclusive** with `article_id`.

          required: false
          type: string
          x-example: manufacturer_id_1
```  

#### Example of an Alternative Design Approach

Based on the example above, we expose filtering of orders by article id as a separate resource.  

```yaml
paths:
  /articles/{article_id}/orders:
    x-summary: Collection of Orders for given Article 

    get:
      summary: Retrieve the collection of Orders that contain given article.
```

---

## [Changes and Versioning](#changing-versioning)

### [Basic Rules (api-peak:rest38:2025-basic-versioning)](#basic-versioning)

> "The fundamental rule is that you can't break existing clients, since you don't know what they implement, and you don't have control over them. So you must turn an incompatible change into a compatible one."  
> – [Mark Nottingham](https://www.mnot.net/blog/2011/10/25/web_api_versioning_smackdown)

A change to the API **MUST NOT** cause problems with the operation of existing clients.

Changes to:

1. The resource identifier (resource name / URI), including query parameters and their semantics.
2. Resource metadata (e.g. HTTP headers).
3. Actions available for the resource (e.g. available HTTP methods).
4. Relationships with other resources (e.g. links).
5. The representation format (e.g. HTTP request and response bodies).

**MUST** conform to the Rules of Extensibility.

### [Rules of Extensibility (api-peak:general10:2025-rules-of-extension)](#rules-of-extending)

- You **MUST NOT** remove anything (related: [Minimal Surface Principle](https://en.wikipedia.org/wiki/YAGNI), [Robustness Principle](https://en.wikipedia.org/wiki/Robustness_principle))
- You **MUST NOT** change processing rules
- You **MUST NOT** make optional things required
- Anything you add **MUST** be optional (related: [Robustness Principle](https://en.wikipedia.org/wiki/Robustness_principle))

### [Identifier Stability (No URI Versioning) (api-peak:rest39:2025-id-stability)](#id-stability)

A change **MUST NOT** affect existing resource identifiers (names / URIs). In addition, a resource identifier **SHOULD NOT** contain a semantic version to convey the version of the resource or its representation format.

> "The reason to create a true REST API is to gain the ability to evolve... 'v1' is a middle finger to your API's clients and a sign you're brewing a REST-like API over RPC/HTTP."  
> – Roy T. Fielding

#### Example

Adding a new action to an existing resource identified by `/greeting` does NOT change its identifier to `/v2/greeting` (or `/greeting-with-new-action`, etc.).

### [Backward-Incompatible Changes (api-peak:rest40:2025-backwards-incompatibility)](#backwards-incompatibility)

A change to a resource identifier, resource metadata, resource action, or relationship between resources that cannot conform to the Rules of Extensibility **MUST** result in the creation of a new resource variant version. The existing resource variant **MUST** be preserved.

A change to the representation format **SHOULD NOT** result in the creation of a new resource variant.

#### Example  

The currently optional query parameter `first` in the existing resource `/greeting?first=John&last=Appleseed` must become required. Since this change violates the third Rule of Extensibility and may cause problems for existing clients, a new resource variant is created with a different URI: `/named-greeting?first=John&last=Appleseed`.


### [Representation Format Changes (api-peak:rest41:2025-representation-format-change)](#representation-format-change)

The representation format is the serialization format (media type) used in HTTP request and response bodies, which typically represents a resource or part of it, possibly with additional hypermedia controls.

If a change cannot conform to the Rules of Extensibility, the representation format's media type **MUST** be changed. If the media type has been changed, the previous media type **MUST** remain available through content negotiation.

If the media type includes a version parameter, that parameter **SHOULD** conform to semantic versioning.

#### Example

Media type before the breaking change:  

```text
application/vnd.example.resource+json; version=2
```

Media type after the breaking change:  

```text
application/vnd.example.resource+json; version=3
```

> **NOTE:** In the case of technical constraints related to semicolon-separated HTTP header values, the semantic version **MAY** be included in the media type identifier, e.g.:  

> ```
> application/vnd.example.resource.v2+json
> ```

> However, using semicolon-separated version information is preferred.


### [API Description Versioning (api-peak:rest42:2025-api-description-versioning)](#api-description-versioning)

The API description in OpenAPI specification format **MUST** include a `version` field. The `version` field **MUST** conform to semantic versioning:

- Increment the MAJOR version when introducing incompatible changes to the API.
- Increment the MINOR version when adding functionality in a backward-compatible manner.
- Increment the PATCH version when making backward-compatible bug fixes.

The API description version **SHOULD** be updated in accordance with API design changes.

#### Example

The following API description:  

```yaml
swagger: '2.0'
info:
  version: '2.1.3'
  title: 'Inventory API'
  description: 'Inventory service API'
```

Has MAJOR = 2, MINOR = 1, and PATCH = 3.

### Recommended Reading
- [Evolving HTTP APIs](https://www.mnot.net/blog/2012/12/04/api-evolution)
