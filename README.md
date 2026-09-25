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
- **oasdiff** — blocks backward-incompatible contract changes on every PR.
- **Microcks** — live mocks from the contract, and contract testing of the running implementation.
- **KrakenD** — API gateway whose config is generated from the contract and deployed by CI.
- **Backstage** — API catalog that discovers contracts from Gitea, with the API guidelines as TechDocs.

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

Requires Docker Desktop (Compose), or Podman with `podman-compose` (see "Running on Podman" below). From the repo root:

```bash
docker compose --profile contract --profile catalog --profile gateway up -d
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

A third one-shot service, **ci-image**, builds the image CI jobs run in
(`ci-image/Dockerfile`: node:20 with Spectral, oasdiff, the KrakenD CLI and
js-yaml preinstalled). Building it the first time needs the internet; after
that, CI runs download nothing (the checkout is plain `git` against Gitea).

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
| backend | http://localhost:8081 | provider under test |
| KrakenD | http://localhost:8090 | API gateway routing to the backend |
| Orders API mock | http://localhost:8080/rest/Orders+API/1.0.0/orders/123 | Microcks mock served from the contract's examples |
| API guidelines | http://localhost:7007/docs/default/component/api-guidelines | the rules as TechDocs in Backstage; every Spectral error links to its rule here |

### Running on Podman

The compose file mounts `/var/run/docker.sock`, which rootless Podman doesn't
have. Point the three services that use it at the Podman socket with a
`docker-compose.override.yml` next to `docker-compose.yml` (git-ignored, machine
specific; enable the socket with `systemctl --user enable --now podman.socket`):

```yaml
services:
  gitea-seed:
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock
  gitea-runner:
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock
  krakend-deployer:
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock
```

Then use `podman-compose` instead of `docker compose` (same arguments).
Two Podman differences: restarting a container that depends on `gitea-seed`
(`backstage`, `gitea-runner`) runs the seed again, and `backend` can't be
recreated while `krakend` (which depends on it) runs.

## The demo loop

After the stack is up, governance runs through pull requests **in the consumer
repo** (`example/` → Gitea `governance-demo/devops-api-governance`):

1. Branch → edit `contracts/orders-openapi.yaml` and/or `backend/` → open
   a PR into `main` in Gitea.
2. Gitea Actions runs four gates **in order** (`pr-governance.yml`), each gated
   by `needs:` so the next stage only runs if the previous one passed:
   - **Spectral** (`spectral-openapi-check`) — clones the governance repo for the
     ruleset, then lints the OpenAPI files changed in the PR, **fails on
     error-severity findings**. Each finding links to its rule in the API
     guidelines in Backstage.
   - **Backwards-compatibility** (`breaking-changes-check`) — uses a pinned
     [`oasdiff`](https://github.com/oasdiff/oasdiff) (v1.19.0, preinstalled in the CI image) and diffs every
     PR-modified `*openapi*.{yml,yaml}` against its version on the PR's base
     branch. **Fails on any ERR-severity breaking finding** (`--fail-on ERR`).
     Brand-new files (no baseline) and identical-content edits are skipped;
     the whole job is skipped on `workflow_dispatch` (no PR base ref).
   - **Microcks contract test** (`contract-test`) — imports the PR branch's
     contract (which also updates the live mock) and tests the running
     `backend` against it via the Microcks REST API; **fails on contract drift**.
   - **Gateway deploy** (`gateway-deploy-check`) — generates a KrakenD gateway
     config from the PR's contract, deploys it to a running KrakenD instance,
     and re-runs the Microcks test suite against the gateway instead of the
     backend directly; **fails on any config-lint error or gateway-level
     contract-test failure**.
3. On merge, Backstage's Gitea provider discovers `catalog-info.yaml` from `main`
   and the API entity appears/updates in the catalog (it rescans every 10 s, a
   demo setting in `app-config.yaml`).

A step-by-step walkthrough (green/red for each gate + merge→catalog) is in
[`docs/ci-test-path.md`](docs/ci-test-path.md).

## Repository layout

**Root** — orchestrator + meta:

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | All services + the seed services + profiles (`contract`, `catalog`, `gateway`). |
| `scripts/` | `seed-gitea.sh`, `seed-microcks.sh` — orchestration run by the seed services. `scripts/demo/` — tooling for the recorded stage-by-stage demo, behind one `demo` command (`scripts/demo/demo install`; see `presentation/screenplay.md`). |
| `runner-config.yaml` | Joins CI job containers to `gitea-network` and runs them in the CI image. |
| `ci-image/` | Job image (node:20 + Spectral, oasdiff, KrakenD CLI, js-yaml preinstalled), built by the `ci-image` compose service, so CI runs don't download anything. |
| `presentation/` | The talk deck (`.pdf` + `.txt` transcript) and the recorded demo's docs: `screenplay.md`, `cue-card.md`, `deck-changes.md` (see "Recorded demo"). |
| `tests/` | `pr-governance.feature.md` — BDD walkthrough of the PR loop. |
| `docs/` | `demo-isolation.md` (two-repo model), `ci-test-path.md` walkthrough, `ci-fixes-scope.md` (CI design rationale). |
| `gitea-data/`, `runner-data/` | Local runtime state, git-ignored, disposable. |

**Governance context** ([`governance/`](governance/)) — policy + catalog app:

| Path | Purpose |
|------|---------|
| `governance/spectral/` | `spectral-ruleset.yaml` + `spectral-functions/` + `examples/` — rules (policy as code), pushed to the `api-governance` Gitea repo and linked by consumer CI. |
| `governance/gateway/` | `generate.js` (OpenAPI→KrakenD generator) + `krakend-base.json` + `deployer/` (sidecar that deploys generated configs to the running KrakenD instance) — the generator is pushed to the `api-governance` Gitea repo and linked by consumer CI; `deployer/` is platform-only, never cloned by consumer CI. |
| `governance/api-guidelines/` | `docs/index.md` (the API design guidelines the rules encode) + `catalog-info.yaml` + `mkdocs.yml` — published to the `api-governance` Gitea repo and surfaced in Backstage as TechDocs. |
| `governance/api-catalog/` | The Backstage app (committed source; builds entirely in Docker). |

**Consumer repo** ([`example/`](example/)) — the product unit / starting template, pushed by `gitea-seed` into its own Gitea repo:

| Path | Purpose |
|------|---------|
| `contracts/orders-openapi.yaml` | The live OpenAPI contract (imported into Microcks). |
| `catalog-info.yaml` | Backstage entities (API + Component + Group) discovered from Gitea. |
| `backend/` | Minimal provider-under-test (conformant, or drifting via `DRIFT=true`). |
| `.gitea/workflows/pr-governance.yml` | One PR gate, four stages ordered via `needs:`: `spectral-openapi-check` (linked ruleset) → `breaking-changes-check` (oasdiff) → `contract-test` (Microcks) → `gateway-deploy-check` (KrakenD). |

## Governance rules (Spectral)

The ruleset extends Spectral's built-in OpenAPI rules with organization-specific
checks based on the API guidelines (`governance/api-guidelines/docs/index.md`). Examples:

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
v1.19.0 (pinned, preinstalled in the CI image; the job installs it itself on a plain runner — no host install needed) to
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

`backend` implements the Orders API contract. To prove the gate:

```bash
# Conformant -> contract test passes (green).
# Drift -> contract test fails (red):
BACKEND_DRIFT=true docker compose --profile contract up -d backend
# ...open a PR... then restore:
BACKEND_DRIFT=false docker compose --profile contract up -d backend
```

Microcks uber is all-in-one (no Keycloak, embedded in-memory Mongo), so imported
contracts are ephemeral and re-imported on each run.

## Backstage catalog

Committed under `governance/api-catalog/` and built entirely in Docker (Node 24 in-image — no
host Node). It serves frontend + backend on port 7007 and authenticates to Gitea
with the seeded admin credentials. The Gitea provider scans the `governance-demo`
org for `catalog-info.yaml` (every 10 s in this demo) and renders the API with
its OpenAPI document and a link to the Microcks mocks/tests. The governance
repo's `api-guidelines` component carries the API guidelines as TechDocs
(**Docs** → `api-guidelines`); the Spectral rule messages link to the rule's
anchor on that page.

> The official `@microcks/microcks-backstage-provider` (0.0.7) is **not** used —
> it depends on removed Backstage packages and crashes startup on current
> Backstage. Microcks is surfaced via a link on the API entity instead.

## Roadmap status

This demo originally stopped at design-time linting. All four roadmap
directions are now **implemented**:

- ✅ **Central API catalog** — Backstage discovers contracts from the Gitea org.
- ✅ **Provider contract testing (Microcks)** — running impl tested vs contract in CI.
- ✅ **Backwards-compatibility checks (oasdiff)** — PR diff of each modified
  `*openapi*.{yml,yaml}` vs the base branch fails the gate on breaking changes
  (new required parameters, narrowed types, removed response fields, removed
  operations, …). Aligns with the guidelines' semver and rules-of-extensibility sections.
- ✅ **API gateway (KrakenD)** — the PR's contract is deployed to a real
  KrakenD CE gateway and re-tested through it before merge, closing the
  loop from design-time lint through to a running, routable gateway.

## Operational notes

- **Docker socket**: `gitea-runner`, `gitea-seed`, and `krakend-deployer` mount
  `/var/run/docker.sock` (runner starts job containers; seed runs `gitea` CLI;
  the deployer restarts `krakend` with a freshly generated config). Local-demo
  convenience, not a hardened pattern. `krakend-deployer`'s `/deploy` endpoint
  is deliberately unauthenticated and reachable from anything on the compose
  network, but its blast radius is narrow — write one config file, restart one
  named container — narrower than the socket access job containers had before
  an earlier fix removed it.
- **Runner network and image**: `runner-config.yaml` puts CI job containers on
  `gitea-network` so checkout reaches `http://gitea:3000/`, and runs them in the
  local CI image (`localhost/devops-api-governance-ci:latest`).
- **Re-seeding**: every `up` runs `gitea-seed`, which force-pushes `example/`
  over the Gitea consumer repo's `main` (and the governance repo). Anything you
  did in Gitea's `main` is replaced by the committed template.
- **Backstage config**: `governance/api-catalog/app-config.yaml` is mounted, so config changes
  need only a `restart` (not a rebuild). For host `yarn dev`, override the compose
  service-name hosts with `localhost` in `governance/api-catalog/app-config.local.yaml`.

## Stop / reset

```bash
docker compose --profile contract --profile catalog --profile gateway down        # stop
docker compose --profile contract --profile catalog --profile gateway down -v     # + drop seeded volumes
rm -rf gitea-data runner-data                                    # + drop Gitea/runner state
```

For the recorded demo, `demo fresh` does the full wipe and brings the stack back
at the Stage 1 start (see "Recorded demo" below).

## Reproduce the demo

This demo covers five topics, in the order the talk tells them. Below is how to run each one live; for the recorded, stage-by-stage version see "Recorded demo". Full
PR-driven flows are in
[`tests/pr-governance.feature.md`](tests/pr-governance.feature.md).

**Setup.** Bring the stack up and clone the consumer repo (all demos run against
it, never against this project):

```bash
docker compose --profile contract --profile catalog --profile gateway up -d      # up + auto-seed
mkdir -p ~/demo && cd ~/demo
git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git orders-api
cd orders-api
```

Clone it outside this project and under another name: the Gitea repo is also
called `devops-api-governance`, so a default clone next to or inside this
project collides with it.

Endpoints: Gitea `:3000` (`demo`/`demo12345`) · Microcks `:8080` · Backstage
`:7007` (guest) · backend `:8081` · KrakenD `:8090`.

**Topic 1 — API Catalog.** One `catalog-info.yaml` makes an API org-wide visible.
Backstage → **APIs** shows `orders-api`, auto-discovered from Gitea; its
**Definition** tab has the rendered contract + owner + docs.

**Topic 2 — Guidelines as Code.** The guidelines live in the catalog (Backstage →
**Docs** → `api-guidelines`) and run as Spectral checks in CI. In the cloned
consumer repo, branch, break a rule (e.g. server URL `http://` instead of
`https://`), and open a PR in Gitea → Actions runs `spectral-openapi-check` →
**red**, with rule · file · line and a link to the rule in the catalog. Fix it,
push again → **green**.

**Topic 3 — Mocking & Contract Testing.** Microcks serves a live mock from the
spec (`curl http://localhost:8080/rest/Orders+API/1.0.0/orders/123`, or Microcks
UI → `Orders API`) and tests the running backend for drift. Make the contract
promise a field the backend doesn't return (e.g. a required `currency`) and the
`contract-test` gate goes **red**; keep the contract in line with the code →
**green**.

**Topic 4 — API Gateway.** The contract isn't just tested against the backend —
it's deployed. Open a PR, and the `gateway-deploy-check` gate generates a
KrakenD config from the contract, deploys it to a real KrakenD CE gateway, and
re-runs the same Microcks test suite through the gateway (`:8090`) instead of
the backend directly → **green** when the gateway routes and proxies
transparently. Break the contract (e.g. an operation `krakend check` can't
route) and the gate goes **red** before the gateway ever restarts.

**Topic 5 — Breaking Changes.** A new *required* request parameter (e.g. a
`channel` query parameter on `GET /orders/{orderId}`) breaks every client that
doesn't send it. Open a PR with that change → the `breaking-changes-check` gate
(oasdiff, `new-required-request-parameter`) blocks it → **red**, and the later
gates are skipped. Make the parameter optional, push again → **green**.

## Recorded demo

The talk plays back five recordings, one per topic above, in which the pipeline
grows by one gate at a time. Everything for them is in `presentation/` and
`scripts/demo/`:

| File | What it is |
|------|------------|
| [`presentation/screenplay.md`](presentation/screenplay.md) | The full script: per stage, what is on screen, terminal and browser steps, expected results, measured timings, retakes. |
| [`presentation/cue-card.md`](presentation/cue-card.md) | The same on one page, to keep next to the recording. |
| [`presentation/deck-changes.md`](presentation/deck-changes.md) | What to change in the slide deck (per PDF page) to match the recordings. |
| `scripts/demo/` | The tooling behind the `demo` command below. |

One-time setup: `scripts/demo/demo install` (adds one line to `~/.bashrc`), then
open a new terminal. `demo` works from any directory and completes with Tab:

```bash
demo preflight            # "ready to record?" check, ends with READY or a list of problems
demo next                 # prepare the next step's branch (run after each merge)
demo status               # where the demo is and what comes next
demo goto 3-red           # retake: roll back to the start of any step
demo fresh                # wipe the demo Gitea before the final take (PRs start at #1)
demo shell                # set up the recording terminal (prompt with branch, cd into the clone)
demo rehearse             # full dry run of the screenplay against the stack (~9 min)
demo cards ~/demo/cards   # title cards; also: demo trim | speed | concat
```

## License

Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Share
and adapt with attribution — see [LICENSE](LICENSE).
