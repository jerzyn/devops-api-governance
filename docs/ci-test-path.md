# CI test path: green/red walkthrough

This is a narrative summary of the PR gate path. For the full scripted
scenarios (exact edits, exact red/green transitions, exact fixes), see
[`tests/pr-governance.feature.md`](../tests/pr-governance.feature.md) — this
page is deliberately not a copy of it.

## The path

A PR into `main` on the consumer repo runs three gates in order (each gated
by `needs:`, so a failure stops the rest):

1. **`spectral-openapi-check`** — lints the PR's changed OpenAPI files
   against the linked governance ruleset.
   - 🔴 **Red**: any error-severity rule violation (e.g. an `http://` server
     URL, a missing `summary`). The other two gates are skipped.
   - 🟢 **Green**: zero errors (warnings/info don't block).
2. **`breaking-changes-check`** — diffs each modified OpenAPI file against
   its version on the PR's base branch with `oasdiff`.
   - 🔴 **Red**: any breaking change (new required parameter, narrowed
     constraint, removed field/operation). `contract-test` is skipped.
   - 🟢 **Green**: no breaking findings, or nothing to diff (new file, no
     OpenAPI change, or `workflow_dispatch`).
3. **`contract-test`** — imports the PR branch's contract into Microcks and
   runtime-tests the running `sample-backend` against it.
   - 🔴 **Red**: the backend's actual responses don't match the contract
     (drift, or a contract change the backend doesn't implement yet).
   - 🟢 **Green**: backend behavior matches the contract.

## After merge

Once all three gates are green and the PR merges to `main`, Backstage's
Gitea provider picks up `catalog-info.yaml` from `main` and the
`sample-orders-api` entity in the catalog reflects the new contract
(possibly after a restart, if you don't want to wait for the provider's
refresh interval).

## Where to actually see this happen

- Gitea PR checks — pass/fail per gate.
- Each job's log — rule IDs, `oasdiff` findings, or the Microcks test link.
- Backstage `http://localhost:7007` — the catalog entity after merge.
