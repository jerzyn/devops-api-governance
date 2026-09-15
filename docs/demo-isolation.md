# Demo isolation: the two-repo model

The demo is split into two repos so a product team's repo stays separate from
the platform that governs it. This project's working tree contains both, but
they play different roles and get pushed to two separate Gitea repos on `up`.

## Governance context (this project → `governance-demo/api-governance`)

[`governance/`](../governance/) is the policy: the Spectral ruleset + its
custom functions ([`governance/spectral/`](../governance/spectral/)), the
guidelines doc + its TechDocs wiring
([`governance/api-guidelines/`](../governance/api-guidelines/)), and the
Backstage catalog app ([`governance/api-catalog/`](../governance/api-catalog/)).
Single source of truth for the rules.

`docker-compose.yml`, `scripts/`, and `runner-config.yaml` stay at the repo
root rather than under `governance/` — they're orchestration that wires
`governance/` and `example/` together, not policy content.

## Consumer repo ([`example/`](../example/) → `governance-demo/devops-api-governance`)

The product unit: the OpenAPI contract, `catalog-info.yaml`, the backend
implementation, and a thin PR workflow. It is the **starting template** —
`gitea-seed` materializes it into a fresh Gitea repo on every `up`, and **all
PRs in the demo happen against that Gitea repo** (clone it, branch, PR). Test
PRs never touch this project's own git history.

## Why "linked, not vendored"

The consumer's CI workflow ([`example/.gitea/workflows/pr-governance.yml`](../example/.gitea/workflows/pr-governance.yml))
does not carry a copy of the Spectral ruleset. Its `spectral-openapi-check`
job clones `governance-demo/api-governance` at run time and lints against
that clone. This means:

- The governance repo is the **only** place the ruleset is edited — no
  version drift between "the rules" and "a copy of the rules some consumer
  repo happens to have."
- Every consumer repo in the org (in a real setup, not just this demo) picks
  up a ruleset change on its next PR, with no separate publish/update step.
- The tradeoff: a broken or unreachable governance repo blocks every
  consumer's CI. This demo doesn't address that failure mode — it's a
  single-tenant local stack, not a resilience exercise.

See [`README.md`](../README.md) for the full service layout and how to bring
the stack up.
