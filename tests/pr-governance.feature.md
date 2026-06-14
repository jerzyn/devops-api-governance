# Feature: PR API governance loop (BDD)

First-timer walkthrough. Acceptance scenario for the governance pipeline:
**design-time lint (Spectral, linked ruleset) → runtime contract test (Microcks)
→ catalog discovery (Backstage)**, driven through pull requests against the
seeded Gitea **consumer** repo.

Architecture (see [`../docs/demo-isolation.md`](../docs/demo-isolation.md)):
- **Governance context** = this project (`governance/` policy + `api-catalog/`).
- **Consumer repo** = `example/`, materialized by `gitea-seed` into the Gitea repo
  `governance-demo/devops-api-governance`. PRs happen against that Gitea repo.
- The consumer CI **clones** the governance ruleset at run time (not vendored).

## Background

```gherkin
Background:
  Given a fresh clone of this project and Docker Desktop running
  When I run:
    """
    docker compose --profile contract --profile catalog up -d
    """
  Then gitea-seed creates org "governance-demo" and two repos:
    | repo                                  | content                          |
    | governance-demo/devops-api-governance | consumer (from example/)         |
    | governance-demo/api-governance        | policy (ruleset + functions)     |
  And these are reachable:
    | Gitea          | http://localhost:3000 | demo / demo12345     |
    | Microcks       | http://localhost:8080 | mocks + test results |
    | Backstage      | http://localhost:7007 | guest sign-in        |
    | sample-backend | http://localhost:8081 | provider under test  |
  And I clone the consumer repo to work on it:
    """
    git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git
    """
  And before every scenario I cut a fresh branch off main (never edit main):
    """
    git switch -c test/<scenario-name> main
    """
```

> ⚠️ **Always branch before testing.** Make every change on a new branch off
> `main`, never on `main` itself, so the seeded `example/` starting state is
> never lost. `main` stays the pristine template; throw the test branch away
> when done (`git push origin --delete <branch>`), and re-run `gitea-seed` to
> reset the consumer repo to the template.

The consumer repo ships seeded with the Sample Orders API (`GET /orders/{orderId}`)
and a conformant backend. Each scenario opens a PR against it.

---

## Scenario 1: a non-compliant change is blocked, then driven to green

Demonstrates both gates in order: a bad change fails Spectral; once Spectral
passes, a contract drift fails Microcks; once fixed, both go green and merge
updates the catalog.

```gherkin
Scenario: PR #1 — tighten the contract, fix lint, fix drift, merge

  # --- open the PR (gate 1 RED) ---
  Given a branch "feat/orders-currency" off main in the consumer clone
  When I edit contracts/orders-openapi.yaml to add a "currency" field
       AND I (accidentally) set the server URL to http:// instead of https://
  And I push and open a PR into main
  Then the "spectral-openapi-check" stage runs first and FAILS
    # CI clones governance-demo/api-governance and lints against its ruleset;
    # custom rule pzu:rest17:2025-https-required (error) fires.
  And the "contract-test" stage is SKIPPED (gated by needs:)
  And the PR check is red

  # --- fix Spectral (gate 1 GREEN, gate 2 RED) ---
  When I commit a fix: restore the https:// server URL
       AND mark "currency" required in the 200 response schema
       AND add "currency" to the response example
    # (Spectral validates examples against the schema, so a required field
    #  missing from the example is itself an error — add it to keep lint green.)
  Then "spectral-openapi-check" PASSES
  And "contract-test" now runs and FAILS
    # the conformant backend returns no "currency" -> schema mismatch:
    #   "required property 'currency' not found"
  And the report link in the CI log is browser-reachable:
    """
    Details: http://localhost:8080/#/tests/<id>
    """
  And the contract under test is the PR branch's version (not main)

  # --- fix the mismatch (both GREEN) ---
  When I commit a fix: drop the "currency" requirement (match the backend)
  Then "spectral-openapi-check" PASSES
  And "contract-test" PASSES
  And both PR checks are green

  # --- merge -> catalog ---
  When I merge the PR into main
  Then Backstage's Gitea provider discovers catalog-info.yaml from main
  And the API "sample-orders-api" shows the updated contract
    # (restart backstage to force re-discovery if you don't want to wait)
```

**Driving the red states**
- Spectral red: the `http://` server URL trips an error-severity rule.
- Microcks red — two easy ways:
  - tighten the PR's contract (above): proves the **PR branch** contract is used.
  - or drift the provider: `SAMPLE_BACKEND_DRIFT=true docker compose --profile contract up -d --force-recreate sample-backend` (restore with `false`).

---

## Scenario 2: evolve the API (new version + new endpoint)

```gherkin
Scenario: PR #2 — bump to 1.1.0 and add GET /orders

  Given a branch "feat/orders-list" off main in the consumer clone

  # --- gate 1 RED then GREEN ---
  When I edit contracts/orders-openapi.yaml: bump info.version to 1.1.0
       AND add a GET /orders list endpoint (with examples)
  And I open a PR into main
  Then "spectral-openapi-check" FAILS until every new-path rule is satisfied
    # e.g. the new /orders path needs a `summary` (rule pzu:rest12, error)
  When I commit the Spectral fixes
  Then "spectral-openapi-check" PASSES

  # --- gate 2 RED (backend lacks the endpoint) ---
  And "contract-test" runs and FAILS
    # CI derives the service version from the contract (1.1.0) and tests it:
    #   GET /orders -> "Expecting 200 but got 404"

  # --- implement, rebuild, GREEN ---
  When I add GET /orders to sample-backend, commit, and rebuild the provider:
    """
    docker compose --profile contract up -d --build --force-recreate sample-backend
    """
  Then "contract-test" PASSES (re-run the PR job after the rebuild)
  And both checks are green

  # --- merge -> catalog shows the new version ---
  When I merge the PR into main
  Then Backstage shows sample-orders-api at version 1.1.0 with paths
       /orders and /orders/{orderId}
```

> Note: `sample-backend` is built from `example/sample-backend`, and the contract
> test targets the **running** container. After changing the backend, rebuild +
> force-recreate it, then re-run the PR's CI job so it tests the new build.

---

## Acceptance summary

| # | Step | Expected | Verify at |
|---|------|----------|-----------|
| 1 | Bad change opened | Spectral RED (linked ruleset), Microcks skipped | Gitea PR checks |
| 2 | Spectral fixed | Spectral GREEN, Microcks RED | Gitea PR checks + CI log |
| 3 | Report link | `http://localhost:8080/...` (not `microcks-uber`) | contract-test CI log |
| 4 | Contract under test | PR branch version; service version derived from contract | CI log "Testing service: ...:<version>" |
| 5 | Mismatch fixed | Spectral GREEN, Microcks GREEN | Gitea PR checks |
| 6 | Merge to main | API discovered / updated | Backstage http://localhost:7007 |

These map to the CI design in [`../docs/ci-fixes-scope.md`](../docs/ci-fixes-scope.md):
linked ruleset, ordering (`needs:`), report URL, PR-branch contract, version-derive.
