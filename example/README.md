# Sample Orders API — consumer repo (starting template)

This is the **product/consumer repository**: the API contract, its catalog
entry, and the backend implementation. It is the unit a product team owns and
opens pull requests against.

It is also the **starting template** — copy this folder to bootstrap a new
governed API repo.

## Contents

| Path | Purpose |
|------|---------|
| `contracts/orders-openapi.yaml` | The OpenAPI contract (source of truth for the API). |
| `catalog-info.yaml` | Backstage entities (API + Component + Group), discovered from Gitea. |
| `sample-backend/` | The provider implementation tested against the contract. |
| `.gitea/workflows/pr-governance.yml` | PR gate: Spectral lint → backward-compat check → Microcks contract test → KrakenD gateway deploy. |

## Governance is linked, not vendored

The Spectral ruleset and its custom functions are **not** stored here. The PR
workflow clones the central governance repo (`governance-demo/api-governance`)
at run time and lints against its ruleset. Rules stay single-source in the
governance context; this repo only carries the API.

## PR loop

1. Branch, edit `contracts/orders-openapi.yaml` and/or `sample-backend/`.
2. Push, open a PR into `main` in Gitea (`http://localhost:3000`, `demo` / `demo12345`).
3. Gitea Actions runs `pr-governance.yml`, four gates in order (each gated by
   `needs:`, so a failure stops the rest):
   - **spectral-openapi-check** — lints PR-changed OpenAPI files against the
     linked governance ruleset; fails on error-severity findings.
   - **breaking-changes-check** — diffs modified OpenAPI files against the PR's
     base branch with `oasdiff`; fails on any breaking change (new required
     parameter, narrowed constraint, removed field/operation).
   - **contract-test** — imports this PR's contract into Microcks and tests the
     running `sample-backend` against it; fails on drift.
   - **gateway-deploy-check** — generates a KrakenD gateway config from this
     PR's contract, deploys it to a running KrakenD instance, and re-runs the
     same Microcks test suite through the gateway instead of directly against
     the backend; fails on a bad config or a gateway-level contract mismatch.
4. Merge → Backstage re-discovers `catalog-info.yaml` and updates the API entity.

The platform that runs Gitea, Microcks and Backstage lives in the governance
context one level up. See its `docs/demo-isolation.md`.
