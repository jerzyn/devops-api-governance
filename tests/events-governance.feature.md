# Feature: PR governance loop for async APIs (BDD)

Acceptance scenarios for the governance pipeline of an event API, on MQTT and
on Kafka:
**lint (AsyncAPI validate + OpenLint, linked ruleset) → breaking changes
(@asyncapi/diff + Apicurio compatibility) → contract test (Microcks async) →
broker policy (generated from the contract and the catalog) → catalog
(Backstage)**, driven through pull requests against the seeded Gitea repos.

The scenarios follow the order of the recorded demo (`scripts/demo`,
`presentation/cue-card.md`): each gate is introduced, then shown red and
green. The MQTT API lives in the orders repo next to the REST API, so every
scenario's PR also carries the REST half of the step
([`pr-governance.feature.md`](pr-governance.feature.md)); only the event
workflow, `pr-governance-events.yml`, is read here. `demo goto <target>` puts
the stack at the start of any scenario.

## Background

```gherkin
Background:
  Given a fresh clone of this project and Docker (or Podman) running
  When I run:
    """
    docker compose --profile contract --profile catalog --profile gateway --profile events --profile kafka up -d
    """
  Then gitea-seed creates org "governance-demo" with the consumer repos and the shared governance repo:
    | repo                                   | content                                    |
    | governance-demo/devops-api-governance  | orders repo: REST + MQTT (from example/)   |
    | governance-demo/order-events-kafka-api | Kafka consumer (from example-kafka/)       |
    | governance-demo/api-governance         | policy (rulesets, tools, guidelines)       |
  And these are reachable:
    | Gitea      | http://localhost:3000 | demo / demo12345            |
    | Microcks   | http://localhost:8080 | mocks + test results        |
    | Apicurio   | http://localhost:8280 | payload schemas             |
    | Backstage  | http://localhost:7007 | guest sign-in               |
    | MQTT       | localhost:1883        | accounts in mosquitto/users.txt |
  And the MQTT backend publishes OrderCreated and OrderPaid every second
  And the Kafka backend publishes the same events, keyed by order id
  When I run "scripts/demo/demo goto 1"
  Then the orders repo's main holds both contracts and the backends and the subscriber,
       without a catalog entry or a PR workflow
  And the demo clones are at ~/demo/orders-api and ~/demo/order-events-kafka-api,
       each with the next step's branch prepared and not pushed
```

Each scenario below pushes a prepared branch (`demo next` prepares it), opens
a PR into `main` in Gitea and reads the PR's checks. Green PRs are merged; the
next scenario starts from that merge.

---

## Scenario 1: the API appears in the catalog

```gherkin
Scenario: register the Order Events API in Backstage
  Given the branch "feat/add-catalog-entry" (adds catalog-info.yaml)
  When I push it, open a PR and merge it
  Then within seconds Backstage lists the API "order-events-api" of type asyncapi
  And its Documentation tab renders the channels, operations, messages and MQTT bindings
  And its Catalog Graph shows orders-backend providing it, orders-subscriber consuming it,
      both depending on the resource mqtt-broker
```

## Scenario 2: the lint gate blocks a guideline violation

```gherkin
Scenario: a property name that breaks the guidelines is red, the fix is green
  Given the lint gate is merged (branch "feat/add-lint-gates")
  And the branch "feat/orders-server-and-paid-at" adds an optional "paid_at" to OrderPaid
  When I push it and open a PR
  Then "asyncapi-lint" FAILS with
    """
    error  api-peak:async11:2026-property-naming  Property 'paid_at' MUST be camelCase.
    http://localhost:7007/docs/default/component/api-guidelines/async/#property-naming-api-peakasync112026-property-naming
    """
  And the link opens that guideline in Backstage TechDocs
  When I rename the property to "paidAt" and push
  Then "asyncapi-lint" PASSES and I merge
```

```gherkin
Scenario: an invalid AsyncAPI document fails before the guidelines are checked
  Given a branch that sets "action: publish" (an AsyncAPI 2 keyword) on an operation
  When I push it and open a PR
  Then the "Validate" step of "asyncapi-lint" FAILS and the lint step does not run
```

```gherkin
Scenario: every rule fires on the intentionally broken examples
  When I lint governance/openlint/examples/asyncapi-invalid.yaml with asyncapi-mqtt-ruleset.yaml
  Then every api-peak:asyncN and api-peak:mqttN rule reports at least once
  When I lint governance/openlint/examples/asyncapi-kafka-invalid.yaml with asyncapi-kafka-ruleset.yaml
  Then api-peak:kafka1 to api-peak:kafka6 each report once
```

## Scenario 3: the contract test checks what the running backend publishes

```gherkin
Scenario: a field the backend doesn't send is red, sending it is green
  Given the contract-test gate is merged (branch "feat/add-contract-test-gates")
  And the branch "feat/orders-currency" makes "currency" required on OrderCreated
  When I push it and open a PR
  Then "asyncapi-lint" PASSES
  And "contract-test" FAILS: Microcks listened on orders/v1/+/created and every
      message lacks the required "currency"
  And the log links to the test report in Microcks
  When events-backend/server.js adds "currency": "PLN" to OrderCreated and I push
  Then "contract-test" deploys the PR's events-backend into mqtt-backend
  And "contract-test" PASSES on both topics and I merge
```

```gherkin
Scenario: a drifting backend fails the contract test without a contract change
  Given the backend runs with drift: MQTT_BACKEND_DRIFT=true docker compose --profile events up -d mqtt-backend
  When I re-run the workflow of a green PR
  Then "contract-test" FAILS (orderId is a number, createdAt renamed)
  And "docker compose --profile events up -d mqtt-backend" puts the conformant backend back
```

## Scenario 4: the broker enforces the contract

```gherkin
Scenario: the broker policy follows the contract and the catalog
  Given the branch "feat/add-deploy-gates"
  When I push it, open a PR and merge it
  Then "broker-policy" generates the policy from the contract and the catalog:
    | account           | may                                                  |
    | orders-backend    | publish orders/v1/+/created and orders/v1/+/paid     |
    | orders-subscriber | subscribe to orders/v1/+/created and orders/v1/+/paid|
    | microcks          | subscribe to them, publish its mock topics           |
  And applies it to Mosquitto, checks it from the outside and re-runs the contract test
```

```gherkin
Scenario: the broker refuses what the policy does not grant
  When I run "demo deny"
  Then a subscription to orders/v1/+/refunded is denied ("All subscription requests were denied.")
  And a subscription to orders/v1/# is denied
  And a client without an account is refused ("not authorised")
  And on Kafka, reading orders.not-in-contract.v1 fails with
      "Topic authorization failed"
```

```gherkin
Scenario: a consumer taken out of the catalog loses its access
  Given a PR that drops consumesApis from orders-subscriber in catalog-info.yaml
  When its "broker-policy" job applies that PR's policy
  Then the broker disconnects the subscriber and its log shows
    """
    DENIED orders/v1/+/created, orders/v1/+/paid (...): not granted by the broker policy
    """
  And "docker compose --profile events up -d broker-policy-seed" (or demo goto) restores main's policy
```

## Scenario 5: breaking changes are stopped before they reach consumers

```gherkin
Scenario: removing a field is red, deprecating it is green
  Given the breaking-changes gate is merged (branch "feat/add-breaking-changes-gates")
  And "Publish API (main)" registered main's payload schemas in Apicurio
  And the branch "feat/orders-channel-and-is-paid" removes isPaid from OrderPaid
  When I push it and open a PR
  Then the structural diff finds no breaking change (topics and operations are unchanged)
  And the registry check FAILS:
    """
    FAIL  orders/v1/{orderId}/paid (OrderPaid): not FORWARD-compatible with the registered schema
    """
  And "contract-test" and "broker-policy" are SKIPPED
  When I keep isPaid, mark it "deprecated: true" and push
  Then all four gates PASS and I merge
  And "Publish API (main)" registers the new schema version
```

```gherkin
Scenario: a renamed topic is a structural breaking change
  Given a branch that renames orders/v1/{orderId}/paid to orders/v1/{orderId}/payment
  When I push it and open a PR
  Then the structural diff FAILS with "BREAKING  edit /channels/orderPaid/address"
```

```gherkin
Scenario: an optional field is not a breaking change
  Given a branch that adds an optional field to OrderPaid
  When I push it and open a PR
  Then all four gates PASS
```

## Scenario 6: the same gates govern the Kafka API

```gherkin
Scenario: the catalog entry and an optional field pass every gate on Kafka
  Given the branch "feat/kafka-paid-at" in the Kafka repo adds its catalog-info.yaml
      and an optional paidAt
  When I push it and open a PR
  Then "asyncapi-lint" uses asyncapi-kafka-ruleset.yaml (picked from the server protocol)
  And "breaking-changes", "contract-test" (Microcks on kafka://kafka:9094) and
      "broker-policy" (topics and ACLs) PASS
  When I merge it
  Then Backstage lists "order-events-kafka-api" next to the two APIs of the orders repo
```

```gherkin
Scenario: removing a field is red on Kafka too
  Given the branch "feat/kafka-drop-is-paid" removes isPaid from OrderPaid
  When I push it and open a PR
  Then the registry check FAILS: orders.order-paid.v1 is not FORWARD-compatible
```

```gherkin
Scenario: a topic that breaks the Kafka naming rule is red
  Given a branch that renames orders.order-paid.v1 to Orders.OrderPaid
  When I push it and open a PR
  Then "asyncapi-lint" FAILS with api-peak:kafka1:2026-topic-naming
```

```gherkin
Scenario: changing the partition count is breaking on Kafka
  Given a branch that changes partitions of orders.order-created.v1 from 3 to 6
  When I push it and open a PR
  Then the structural diff FAILS with
    """
    BREAKING  edit /channels/orderCreated/bindings/kafka/partitions
    """
```

```gherkin
Scenario: the Kafka backend refuses to send events the registry would reject
  Given the Kafka backend runs with drift:
    """
    KAFKA_BACKEND_DRIFT=true docker compose --profile kafka up -d kafka-backend
    """
  Then its log shows "REJECTED by the registry schema of orders.order-created.v1"
  And no drifted event reaches the topic
  When it also runs with KAFKA_REGISTRY_VALIDATION=false
  Then the drifted events reach Kafka and the contract test FAILS
```
