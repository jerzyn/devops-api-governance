# Feature: PR API governance loop (BDD)

First-timer walkthrough. Acceptance scenario for the governance pipeline:
**design-time lint (Spectral, linked ruleset) → backward-compatibility check
(oasdiff) → runtime contract test (Microcks) → catalog discovery (Backstage)**,
driven through pull requests against the seeded Gitea **consumer** repo.

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

## Scenario 3: backward-incompatible change is blocked by the BC gate

Demonstrates the third gate: a change that is **Spectral-clean** (well-formed
OpenAPI, all rules satisfied) and would **survive contract-test** (the backend
handles it gracefully) is still blocked because it **breaks existing clients**.
The gate uses `oasdiff` v1.19.0 (pinned, installed at job runtime) to diff the
PR-changed `*openapi*.{yml,yaml}` files against their version on
`origin/<base>`.

```gherkin
Scenario: PR #3 — add a required parameter, blocked by BC gate, then relaxed

  Given a branch "feat/orders-currency-required" off main in the consumer clone

  # --- open the PR (gate 2 RED) ---
  When I edit contracts/orders-openapi.yaml: add a NEW REQUIRED query parameter
       `currency` to GET /orders/{orderId}
       AND give the parameter a description, schema with pattern "^[A-Z]{3}$",
       and example value "PLN"
    # The change is Spectral-clean: parameter has description (silences
    # oas3-parameter-description), schema (silences validity checks), and an
    # example that matches the schema (oas3-valid-media-example).
  And I push and open a PR into main

  Then "spectral-openapi-check" PASSES
    # 0 errors from the linked ruleset.
  And "breaking-changes-check" runs and FAILS
    # CI installs oasdiff v1.19.0 (curl tarball from github.com/oasdiff/oasdiff
    # releases, ~6 MB), diffs the file against `origin/main:<path>`, and
    # surfaces the breaking change as a ::error:: annotation:
    """
    ::error file=contracts/orders-openapi.yaml::in API GET /orders/{orderId}
    added the new required `query` request parameter `currency`
    (rule: new-required-request-parameter)
    """
  And "contract-test" is SKIPPED (gated by needs: breaking-changes-check)
  And the PR check is red

  # --- fix: make it backward-compatible ---
  When I commit a fix: drop `required: true` on the `currency` parameter
    # The gate is strict-mode: ONLY making the change backward-compatible
    # (optional parameter, default value, removal, etc.) clears it. Bumping
    # info.version to a new MAJOR alone DOES NOT pass the gate — semver-aware
    # logic is intentionally not wired in this iteration.
  Then "breaking-changes-check" PASSES
    # oasdiff exit 0; no BC findings reported.
  And "contract-test" now runs and PASSES
    # Microcks issues GET /orders/{orderId}?currency=PLN (from the example);
    # the sample-backend ignores unknown query params and returns the same
    # response shape, which matches the unchanged 200 schema.
  And all three checks are green

  # --- merge -> catalog ---
  When I merge the PR into main
  Then Backstage shows the updated contract with the new optional `currency`
       query parameter on GET /orders/{orderId}
    # (restart backstage to force re-discovery if you don't want to wait
    #  for the Gitea provider refresh interval).
```

**Driving the BC gate red — other knobs you can turn**

The gate fires on any `oasdiff breaking` finding. Quick ways to reproduce the
red state on a sandbox PR (all of these are Spectral-clean):

- Add a required **header** (e.g. `Tenant-Id`) to `GET /orders/{orderId}`
  (`new-required-request-parameter`, `in: header`). Use `Hyphenated-Pascal-Case`
  (e.g. `Tenant-Id`, not `X-Tenant-Id`) so Spectral rule
  `pzu:rest10:2025-headers-naming-conventions-x-prefix` (warn) stays clean.
- Narrow the path parameter `orderId`: add `minLength: 5` and/or
  `pattern: "^[A-Z0-9-]+$"` to its schema
  (`request-parameter-min-length-increased`, `request-parameter-pattern-added`).
  Bump the example to match (e.g. `"ABC-123"`) so `oas3-valid-media-example`
  does not turn Spectral red instead.
- Remove an existing response field from the 200 schema
  (`response-property-removed`).

**Edge cases handled by the gate (no scenario, just behaviour)**

| Case                                                            | Behaviour |
|-----------------------------------------------------------------|-----------|
| PR adds a BRAND-NEW `*openapi*.yaml` file (no baseline on main) | skipped (`--diff-filter=M`); BC job passes |
| PR touches an OpenAPI file but content is identical vs main    | skipped via `git diff --quiet`; emits a `::notice::` |
| PR has no `*openapi*.{yml,yaml}` change at all                  | `has_files=false`; oasdiff step not executed |
| Workflow triggered via `workflow_dispatch`                      | whole BC job skipped via `if: github.event_name == 'pull_request'` |

---

## Acceptance summary

| #  | Step | Expected | Verify at |
|----|------|----------|-----------|
| 1  | Bad change opened (Scenario 1, HTTPS rule) | Spectral RED, BC + Microcks SKIPPED (gated by `needs:`) | Gitea PR checks |
| 2  | Spectral fixed (Scenario 1) | Spectral GREEN, BC PASS (response-only additions are non-breaking), Microcks RED | Gitea PR checks + CI log |
| 3  | Microcks report link | `http://localhost:8080/...` (not `microcks-uber`) | contract-test CI log |
| 4  | Contract under test | PR branch version; service version derived from contract | CI log "Testing service: ...:<version>" |
| 5  | Mismatch fixed (Scenario 1) | All three gates GREEN | Gitea PR checks |
| 6  | Merge to main | API discovered / updated | Backstage http://localhost:7007 |
| 7  | Spectral-clean BC opened (Scenario 3) | Spectral GREEN, BC RED, Microcks SKIPPED | Gitea PR checks |
| 8  | oasdiff annotation | `::error::...new required \`query\` request parameter \`currency\`` (or other oasdiff rule ID) | breaking-changes-check CI log |
| 9  | BC fix applied (Scenario 3) | All three gates GREEN | Gitea PR checks |
| 10 | oasdiff version pinned | `oasdiff version 1.19.0` printed in the install step | breaking-changes-check CI log |

These map to the CI design in [`../docs/ci-fixes-scope.md`](../docs/ci-fixes-scope.md):
linked ruleset, ordering (`needs:`), report URL, PR-branch contract, version-derive.
