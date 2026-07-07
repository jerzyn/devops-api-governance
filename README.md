# Governance DevOps Demo

## Quick start

Starter prompt (paste into Claude Code / your agent):

> Get familiar with the repo, prepare the environment, and run the tests in
> `tests/pr-governance.feature.md`. Present a summary as a table with links so I
> can verify the intermediate states.

A local, self-contained demo of API governance across the full delivery loop —
**documented → discovered → delivered** — running entirely on your machine:

- **Gitea** — local Git server + pull requests.
- **Gitea Actions** (`act_runner`) — local CI.
- **Spectral** — policy-as-code lint of OpenAPI on every PR (design-time quality).
- **Microcks** — contract testing of a running implementation against its contract.
- **Backstage** — API catalog that discovers contracts from Gitea.

The goal is not to deploy a production service. It simulates the control points
around API delivery: source control, PRs, automated quality gates, contract
testing, and a discoverable catalog.

## Two repositories

The demo is split so a product team's repo stays separate from the platform that
governs it:

- **Governance context** — [`governance/`](governance/): the policy
  (`spectral/` — ruleset + custom functions + examples, `api-guidelines/` —
  the guidelines doc + its TechDocs wiring) and
  the catalog app (`api-catalog/`). Single source of truth for the rules.
  (`docker-compose.yml`, `scripts/` and `runner-config.yaml` stay at the repo root
  as orchestration that wires `governance/` and `example/` together.)
- **Consumer repo** — [`example/`](example/): the product unit (OpenAPI
  contract + `catalog-info.yaml` + backend implementation) and a thin PR
  workflow. It is the **starting template**: `gitea-seed` materializes it into a
  fresh Gitea repo on each `up`, and **PRs happen against that Gitea repo** (clone
  it, branch, PR) — so test PRs never pollute this project.

The consumer's CI **links** the ruleset (clones the governance repo at run time)
rather than vendoring it. Details: [`docs/demo-isolation.md`](docs/demo-isolation.md).

## One command

Requires Docker Desktop (Compose). From the repo root:

```bash
docker compose --profile contract --profile catalog up -d
```

That brings up everything **and seeds it** — no `.env`, no scripts, no manual
Gitea setup. Two one-shot seed services do the first-run work a plain `up`
cannot:

- **gitea-seed** (after Gitea is healthy): creates the admin (`demo` /
  `demo12345`), the `governance-demo` org, and **two repos** — the consumer repo
  (`devops-api-governance`, pushed from `example/`) and a lean governance repo
  (`api-governance`, ruleset + functions + guidelines). Also writes a runner
  registration token to a shared volume.
- **microcks-seed** (after Microcks starts): imports the OpenAPI contract from
  the consumer repo.

Gitea secrets are auto-generated and persisted in the `gitea-data` volume.
`gitea-runner` and `backstage` wait for `gitea-seed` via compose `depends_on`
conditions; the runner reads its token from the shared volume.

> The seed pushes the **committed** HEAD, so commit your work before `up` for it
> to appear in Gitea / the catalog.

Endpoints:

| Service | URL | Notes |
|---------|-----|-------|
| Gitea | http://localhost:3000 | login `demo` / `demo12345` |
| Microcks | http://localhost:8080 | mocks + contract test results |
| Backstage | http://localhost:7007 | API catalog (guest sign-in) |
| sample-backend | http://localhost:8081 | provider under test |

## The demo loop

After the stack is up, governance runs through pull requests **in the consumer
repo** (`example/` → Gitea `governance-demo/devops-api-governance`):

1. Branch → edit `contracts/orders-openapi.yaml` and/or `sample-backend/` → open
   a PR into `main` in Gitea.
2. Gitea Actions runs three gates **in order** (`pr-governance.yml`), each gated
   by `needs:` so the next stage only runs if the previous one passed:
   - **Spectral** (`spectral-openapi-check`) — clones the governance repo for the
     ruleset, then lints the OpenAPI files changed in the PR, **fails on
     error-severity findings**.
   - **Microcks contract test** (`contract-test`) — imports the PR branch's
     contract and tests the running `sample-backend` against it via the Microcks
     REST API; **fails on contract drift**.
   - **Backwards-compatibility** (`breaking-changes-check`) — installs a pinned
     [`oasdiff`](https://github.com/oasdiff/oasdiff) (v1.19.0) and diffs every
     PR-modified `*openapi*.{yml,yaml}` against its version on the PR's base
     branch. **Fails on any ERR-severity breaking finding** (`--fail-on ERR`).
     Brand-new files (no baseline) and identical-content edits are skipped;
     the whole job is skipped on `workflow_dispatch` (no PR base ref).
3. On merge, Backstage's Gitea provider discovers `catalog-info.yaml` from `main`
   and the API entity appears/updates in the catalog.

A step-by-step walkthrough (green/red for each gate + merge→catalog) is in
[`docs/ci-test-path.md`](docs/ci-test-path.md).

## Repository layout

**Root** — orchestrator + meta:

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | All services + the seed services + profiles (`contract`, `catalog`). |
| `scripts/` | `seed-gitea.sh`, `seed-microcks.sh` — orchestration run by the seed services. |
| `runner-config.yaml` | Joins CI job containers to `gitea-network`. |
| `tests/` | `pr-governance.feature.md` — BDD walkthrough of the PR loop. |
| `docs/` | `demo-isolation.md` (two-repo model), `ci-test-path.md` walkthrough. |
| `gitea-data/`, `runner-data/` | Local runtime state, git-ignored, disposable. |

**Governance context** ([`governance/`](governance/)) — policy + catalog app:

| Path | Purpose |
|------|---------|
| `governance/spectral/` | `spectral-ruleset.yaml` + `spectral-functions/` + `examples/` — rules (policy as code), pushed to the `api-governance` Gitea repo and linked by consumer CI. |
| `governance/api-guidelines/` | `docs/index.md` (the API design guidelines the rules encode) + `catalog-info.yaml` + `mkdocs.yml` — published to the `api-governance` Gitea repo and surfaced in Backstage as TechDocs. |
| `governance/api-catalog/` | The Backstage app (committed source; builds entirely in Docker). |

**Consumer repo** ([`example/`](example/)) — the product unit / starting template (nested, git-ignored):

| Path | Purpose |
|------|---------|
| `contracts/orders-openapi.yaml` | The live OpenAPI contract (imported into Microcks). |
| `catalog-info.yaml` | Backstage entities (API + Component + Group) discovered from Gitea. |
| `sample-backend/` | Minimal provider-under-test (conformant, or drifting via `DRIFT=true`). |
| `.gitea/workflows/pr-governance.yml` | One PR gate, three stages ordered via `needs:`: `spectral-openapi-check` (linked ruleset) → `breaking-changes-check` (oasdiff) → `contract-test` (Microcks). |

## Governance rules (Spectral)

The ruleset extends Spectral's built-in OpenAPI rules with organization-specific
checks based on `api-guidelines.md`. Examples:

- OpenAPI documents must use OpenAPI 3.x.y and should use 3.1.y.
- `info.title` must be Title Case and end with `API`; `info.version` semver.
- JSON properties camelCase; schema names PascalCase; array names plural.
- paths kebab-case, no trailing `/`; URI template vars per RFC 6570.
- HTTPS server URLs; error responses `application/problem+json` with `type`,
  `title`, `detail`.

Severities: `error` (mandatory, fails the gate) · `warn` (recommended) ·
`info` (optional).

### Run Spectral locally

```bash
npx -y @stoplight/spectral-cli lint -r governance/spectral/spectral-ruleset.yaml governance/spectral/examples/openapi-valid.yaml    # passes
npx -y @stoplight/spectral-cli lint -r governance/spectral/spectral-ruleset.yaml governance/spectral/examples/openapi-invalid.yaml  # violations
```

`governance/spectral/examples/openapi-invalid.yaml` intentionally breaks rules (version, title,
HTTPS, naming, Problem Detail, nullable). The CI gate lints only PR-changed
files, so this example does not break unrelated PRs.

## Backwards-compatibility checks (oasdiff)

The `breaking-changes-check` gate uses [`oasdiff`](https://github.com/oasdiff/oasdiff)
v1.19.0 (pinned, installed in the job at run time — no host install needed) to
diff every PR-modified `*openapi*.{yml,yaml}` against its version on the PR's
base branch and **fail on any ERR-severity breaking finding** (`oasdiff
breaking --fail-on ERR`). Typical findings it blocks:

- New required request parameter (query / header / cookie).
- Existing request parameter narrowed (pattern added, `minLength` raised, …).
- Response property removed from an existing operation.
- Operation removed.

Behaviour edge cases (verified in [`tests/pr-governance.feature.md`](tests/pr-governance.feature.md)):

| Case                                                            | Behaviour |
|-----------------------------------------------------------------|-----------|
| PR adds a BRAND-NEW `*openapi*.yaml` file (no baseline on main) | skipped (`--diff-filter=M`); BC job passes |
| PR touches an OpenAPI file but content is identical vs main     | skipped via `git diff --quiet`; emits a `::notice::` |
| PR has no `*openapi*.{yml,yaml}` change at all                  | `has_files=false`; oasdiff step not executed |
| Workflow triggered via `workflow_dispatch`                      | whole BC job skipped via `if: github.event_name == 'pull_request'` |

The gate is **strict-mode**: only making the change backward-compatible
(optional parameter, default value, removal of the new constraint, …) clears
it. Bumping `info.version` to a new MAJOR alone does *not* pass the gate —
semver-aware logic is intentionally out of scope for this iteration.

### Run oasdiff locally

```bash
# Install (Linux amd64). For other platforms, see https://github.com/oasdiff/oasdiff/releases
curl -fsSL -o /tmp/oasdiff.tgz \
  https://github.com/oasdiff/oasdiff/releases/download/v1.19.0/oasdiff_1.19.0_linux_amd64.tar.gz
tar -xzf /tmp/oasdiff.tgz -C /tmp && sudo install -m 0755 /tmp/oasdiff /usr/local/bin/oasdiff

# Diff the PR head against main (annotated, fails on ERR):
oasdiff breaking --fail-on ERR \
  origin/main:contracts/orders-openapi.yaml \
  contracts/orders-openapi.yaml -f githubactions
```

## Contract testing

`sample-backend` implements the Sample Orders API contract. To prove the gate:

```bash
# Conformant -> contract test passes (green).
# Drift -> contract test fails (red):
SAMPLE_BACKEND_DRIFT=true docker compose --profile contract up -d sample-backend
# ...open a PR... then restore:
SAMPLE_BACKEND_DRIFT=false docker compose --profile contract up -d sample-backend
```

Microcks uber is all-in-one (no Keycloak, embedded in-memory Mongo), so imported
contracts are ephemeral and re-imported on each run.

## Backstage catalog

Committed under `governance/api-catalog/` and built entirely in Docker (Node 24 in-image — no
host Node). It serves frontend + backend on port 7007 and authenticates to Gitea
with the seeded admin credentials. The Gitea provider scans the `governance-demo`
org for `catalog-info.yaml` and renders the API with its OpenAPI document and a
link to the Microcks mocks/tests.

> The official `@microcks/microcks-backstage-provider` (0.0.7) is **not** used —
> it depends on removed Backstage packages and crashes startup on current
> Backstage. Microcks is surfaced via a link on the API entity instead.

## Roadmap status

This demo originally stopped at design-time linting. All three roadmap
directions are now **implemented**:

- ✅ **Central API catalog** — Backstage discovers contracts from the Gitea org.
- ✅ **Provider contract testing (Microcks)** — running impl tested vs contract in CI.
- ✅ **Backwards-compatibility checks (oasdiff)** — PR diff of each modified
  `*openapi*.{yml,yaml}` vs the base branch fails the gate on breaking changes
  (new required parameters, narrowed types, removed response fields, removed
  operations, …). Aligns with `api-guidelines.md` semver/extension rules.

## Operational notes

- **Docker socket**: `gitea-runner` and `gitea-seed` mount `/var/run/docker.sock`
  (runner starts job containers; seed runs `gitea` CLI). Local-demo convenience,
  not a hardened pattern.
- **Runner network**: `runner-config.yaml` puts CI job containers on
  `gitea-network` so checkout reaches `http://gitea:3000/`.
- **Backstage config**: `governance/api-catalog/app-config.yaml` is mounted, so config changes
  need only a `restart` (not a rebuild). For host `yarn dev`, override the compose
  service-name hosts with `localhost` in `governance/api-catalog/app-config.local.yaml`.

## Stop / reset

```bash
docker compose --profile contract --profile catalog down        # stop
docker compose --profile contract --profile catalog down -v     # + drop seeded volumes
rm -rf gitea-data runner-data                                    # + drop Gitea/runner state
```

## Reproduce the demo

This demo was presented at **API Days Munich, 07-2026** — four topics. Below is
how to run each one live. Full PR-driven flows are in
[`tests/pr-governance.feature.md`](tests/pr-governance.feature.md).

**Setup.** Bring the stack up and clone the consumer repo (all demos run against
it, never against this project):

```bash
docker compose --profile contract --profile catalog up -d      # up + auto-seed
git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git
```

Endpoints: Gitea `:3000` (`demo`/`demo12345`) · Microcks `:8080` · Backstage
`:7007` (guest) · sample-backend `:8081`.

**Topic 1 — API Catalog.** One `catalog-info.yaml` makes an API org-wide visible.
Backstage → **APIs** shows `sample-orders-api`, auto-discovered from Gitea; its
**Definition** tab has the rendered contract + owner + docs.

**Topic 2 — Guidelines as Code.** The guidelines live in the catalog (Backstage →
`api-governance` → **Docs**) and run as Spectral checks in CI. In the cloned
consumer repo, branch, break a rule (e.g. server URL `http://` instead of
`https://`), and open a PR in Gitea → Actions runs `spectral-openapi-check` →
**red**, with rule · file · line. Fix it, push again → **green**.

**Topic 3 — Mocking & Contract Testing.** Microcks serves a live mock from the
spec (Microcks UI → `Sample Orders API`) and tests the running backend for drift.
Run the contract test from the Microcks UI, or let it run as the `contract-test`
gate on a PR — drift goes red, in-sync goes green.

**Topic 4 — Breaking Changes.** Making an existing field required breaks live
clients. Open a PR with that change → the `breaking-changes-check` gate (oasdiff)
runs and blocks it → **red**. Relax the change to stay compatible, push again →
**green**.

## License

Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Share
and adapt with attribution — see [LICENSE](LICENSE).
