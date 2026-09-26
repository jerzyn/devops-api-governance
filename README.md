# DevOps-Driven API Governance — demo

The demo behind the talk *"DevOps-Driven API Governance"*: API governance built into the delivery loop, running entirely on your laptop.

An OpenAPI contract goes through pull requests in a local Git server, and every PR passes a chain of automated gates:

- **Gitea** + **Gitea Actions** (`act_runner`) — local Git server, pull requests and CI.
- **Backstage** — API catalog that discovers the contract from Gitea, with the API guidelines as TechDocs.
- **Spectral** — the API guidelines as code: lints every contract change.
- **Microcks** — a live mock from the contract, and a contract test of the running backend.
- **KrakenD** — API gateway whose config is generated from the contract and deployed by CI.
- **oasdiff** — blocks backward-incompatible contract changes.

Nothing here is a production setup: it simulates the control points around API delivery (source control, PRs, automated quality gates, contract testing, a discoverable catalog) so you can see and change them.

---

## Requirements

| | Docker | Podman |
|---|---|---|
| Engine | Docker Desktop, or Docker Engine with the Compose plugin (`docker compose version`) | Podman 4+ with [`podman-compose`](https://github.com/containers/podman-compose), rootless |
| OS | Linux, macOS (Intel or Apple Silicon), Windows with WSL2 | Linux (on macOS/Windows, use Docker Desktop) |
| Extra setup | none | enable the Podman socket and point the demo at it (one line, see below) |

Both need:
- **Resources:** ~6 GB of RAM for the engine (Docker Desktop: *Settings → Resources*; the Backstage image build is the heaviest step), ~12 GB of free disk (the images are ~6.5 GB).
- **Internet on the first start**, to pull images and build the Backstage and CI images. After that the demo, including its CI, runs offline.
- **Free ports:** 3000, 2222 (Gitea), 7007 (Backstage), 8080 (Microcks), 8081 (backend), 8090 (KrakenD).
- `git`, `curl` and `bash` (for the optional `demo` helper).

> Tested end to end on Linux with Podman. The Docker instructions use the same compose file and scripts, but weren't run end to end.

## Start

```bash
git clone https://github.com/jerzyn/devops-api-governance.git
cd devops-api-governance
```

**Docker:**

```bash
docker compose --profile contract --profile catalog --profile gateway up -d
```

**Podman:**

```bash
systemctl --user enable --now podman.socket                           # once
echo "DOCKER_SOCK=/run/user/$(id -u)/podman/podman.sock" > .env        # once
podman-compose --profile contract --profile catalog --profile gateway up -d
```

The first start takes a while (images to pull, Backstage and the CI image to build; expect 10–20 minutes). Later starts take under a minute.

`up` also **seeds** everything: no `.env` values, scripts or manual Gitea setup are needed (Podman's `DOCKER_SOCK` aside). One-shot services do the first-run work:

- **gitea-seed** creates the admin user (`demo` / `demo12345`), the `governance-demo` organization and two repos: the consumer repo `devops-api-governance` (from [`example/`](example/)) and the governance repo `api-governance` (ruleset, guidelines, gateway generator). It also writes the CI runner's registration token.
- **microcks-seed** imports the contract into Microcks.
- **ci-image** builds the image CI jobs run in, with Spectral, oasdiff and the KrakenD CLI preinstalled.

### Check that it runs

| Service | URL | Notes |
|---------|-----|-------|
| Gitea | http://localhost:3000 | sign in as `demo` / `demo12345` |
| Backstage | http://localhost:7007 | API catalog (guest sign-in) |
| API guidelines | http://localhost:7007/docs/default/component/api-guidelines | the rules as TechDocs in Backstage; every Spectral error links here |
| Microcks | http://localhost:8080 | mocks and contract test results |
| Orders API mock | http://localhost:8080/rest/Orders+API/1.0.0/orders/123 | served from the contract's examples |
| backend | http://localhost:8081/orders/123 | the implementation under test |
| KrakenD | http://localhost:8090/orders/123 | the gateway; its routes come from the config CI deployed last |

Or, with the `demo` helper (below): `demo preflight` checks everything and ends with `READY` or a list of problems.

## Try it

After `up`, the consumer repo in Gitea has the full pipeline: all four gates. Clone it **outside this project and under another name** (it is also called `devops-api-governance`, so a default clone next to or inside this folder collides with it):

```bash
mkdir -p ~/demo && cd ~/demo
git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git orders-api
cd orders-api
```

Then branch, change `contracts/orders-openapi.yaml`, push, and open a pull request in Gitea. The five topics of the talk:

**1 — API Catalog.** One `catalog-info.yaml` makes an API visible to the whole organization. Backstage → **APIs** shows `orders-api`, discovered from Gitea; its **Definition** tab shows the contract.

**2 — Guidelines as code.** The guidelines live in the catalog (Backstage → **Docs** → `api-guidelines`) and run as Spectral checks in CI. Break a rule (e.g. server URL `http://` instead of `https://`) and open a PR: `spectral-openapi-check` goes **red**, with rule, file, line and a link to the rule in the catalog. Fix it, push again: **green**.

**3 — Mocking & contract testing.** The contract is a live mock at once (`curl http://localhost:8080/rest/Orders+API/1.0.0/orders/123`). Make the contract promise a field the backend doesn't return (e.g. a required `currency`): `contract-test` goes **red**. Keep the contract in line with the code: **green**.

**4 — API gateway.** The contract isn't only tested, it is deployed: `gateway-deploy-check` generates a KrakenD config from the PR's contract, validates it, deploys it to the running gateway and re-runs the same contract test through the gateway (`:8090`).

**5 — Breaking changes.** A new *required* request parameter (e.g. a `channel` query parameter on `GET /orders/{orderId}`) breaks every client that doesn't send it. `breaking-changes-check` (oasdiff, `new-required-request-parameter`) blocks the PR: **red**, and the later gates are skipped. Make the parameter optional: **green**.

### Follow the talk step by step

In the talk the pipeline grows one gate at a time. The `demo` helper puts your Gitea in the state of any step and prepares the change for it, so you can replay the talk:

```bash
scripts/demo/demo install          # once: adds a `demo` command with tab completion to ~/.bashrc; open a new terminal
demo goto 1                        # Stage 1 start: contract only, no catalog entry, no gates
demo status                        # where you are and what comes next
demo shell                         # this terminal: cd into the demo clone (~/demo/orders-api), prompt with the branch
```

Each step is then: `git switch <branch>`, `git push -u origin <branch>`, open the PR in Gitea, merge. After a merge, `demo next` prepares the next step. [`presentation/cue-card.md`](presentation/cue-card.md) lists every step on one page. `demo goto <1|2|2-red|3|3-red|4|5|5-red|end>` jumps to any step, and `demo help` lists the rest.

`demo goto` force-pushes the consumer repo's `main` in *your local* Gitea and closes its open PRs. It never touches this project or GitHub.

---

## How it works

### Two repositories

A product team's repo stays separate from the platform that governs it:

- **Governance** — [`governance/`](governance/): the policy (`spectral/`: ruleset, custom functions, examples; `api-guidelines/`: the guidelines and their TechDocs wiring; `gateway/`: the OpenAPI→KrakenD generator) and the catalog app (`api-catalog/`). Single source of truth for the rules.
- **Consumer** — [`example/`](example/): the product unit (OpenAPI contract, `catalog-info.yaml`, backend) and a thin PR workflow. It is the **starting template**: `gitea-seed` pushes it into a fresh Gitea repo on each `up`, and **PRs happen against that Gitea repo**, never against this project.

The consumer's CI **links** the governance repo (clones it at run time) instead of copying the rules. Details: [`docs/demo-isolation.md`](docs/demo-isolation.md).

### The PR gates

`example/.gitea/workflows/pr-governance.yml` runs four gates **in order**, each gated by `needs:`, so a failure stops the rest:

1. **`spectral-openapi-check`** — clones the governance repo for the ruleset and lints the OpenAPI files changed in the PR. **Fails on error-severity findings.** Each finding links to its rule in the API guidelines in Backstage.
2. **`breaking-changes-check`** — [`oasdiff`](https://github.com/oasdiff/oasdiff) (v1.19.0) diffs every PR-modified `*openapi*.{yml,yaml}` against the PR's base branch. **Fails on any ERR-severity breaking finding** (`--fail-on ERR`). New files (no baseline) and identical-content edits are skipped; the job is skipped on `workflow_dispatch`.
3. **`contract-test`** — imports the PR's contract into Microcks (which also updates the live mock) and tests the running `backend` against it. **Fails on drift.**
4. **`gateway-deploy-check`** — generates a KrakenD config from the PR's contract, validates it (`krakend check`), deploys it to the running gateway and re-runs the Microcks test through the gateway. **Fails on an invalid config or a gateway-level contract mismatch.**

On merge, Backstage's Gitea provider picks up `catalog-info.yaml` from `main` (it rescans every 10 s, a demo setting). A walkthrough of green and red for each gate: [`docs/ci-test-path.md`](docs/ci-test-path.md); scripted scenarios: [`tests/pr-governance.feature.md`](tests/pr-governance.feature.md).

CI jobs run in `localhost/devops-api-governance-ci:latest` ([`ci-image/Dockerfile`](ci-image/Dockerfile), amd64 or arm64) and check out with plain `git` from Gitea, so they download nothing. On a plain `node:20` runner the workflow installs the tools itself.

### Governance rules (Spectral)

The ruleset extends Spectral's built-in OpenAPI rules with checks based on the API guidelines ([`governance/api-guidelines/docs/index.md`](governance/api-guidelines/docs/index.md)), for example:

- OpenAPI 3.x.y (3.1.y recommended); `info.title` in Title Case ending with `API`; semver `info.version`.
- camelCase JSON properties, PascalCase schema names, plural array names.
- kebab-case paths without a trailing `/`; URI template variables per RFC 6570.
- HTTPS server URLs; errors as `application/problem+json` with `type`, `title`, `detail`.

Severities: `error` (fails the gate) · `warn` (recommended) · `info` (optional). Run it locally:

```bash
npx -y @stoplight/spectral-cli lint -r governance/spectral/spectral-ruleset.yaml governance/spectral/examples/openapi-valid.yaml    # passes
npx -y @stoplight/spectral-cli lint -r governance/spectral/spectral-ruleset.yaml governance/spectral/examples/openapi-invalid.yaml  # violations
```

`openapi-invalid.yaml` breaks rules on purpose. The CI gate only lints files changed in the PR, so it doesn't affect other PRs.

### Backwards compatibility (oasdiff)

Typical changes the gate blocks: a new required request parameter; a narrowed request parameter (pattern added, `minLength` raised, …); a response property removed; an operation removed.

| Case | Behaviour |
|------|-----------|
| PR adds a brand-new `*openapi*.yaml` (no baseline on `main`) | skipped (`--diff-filter=M`); the job passes |
| PR touches an OpenAPI file but the content is identical | skipped (`git diff --quiet`), with a `::notice::` |
| PR changes no OpenAPI file | the oasdiff step doesn't run |
| `workflow_dispatch` | the whole job is skipped |

The gate is strict: only a backward-compatible change (optional parameter, default value, dropping the new constraint, …) clears it. Bumping `info.version` to a new major alone doesn't.

```bash
# Linux amd64 (other platforms: https://github.com/oasdiff/oasdiff/releases)
curl -fsSL -o /tmp/oasdiff.tgz https://github.com/oasdiff/oasdiff/releases/download/v1.19.0/oasdiff_1.19.0_linux_amd64.tar.gz
tar -xzf /tmp/oasdiff.tgz -C /tmp && sudo install -m 0755 /tmp/oasdiff /usr/local/bin/oasdiff
oasdiff breaking --fail-on ERR origin/main:contracts/orders-openapi.yaml contracts/orders-openapi.yaml -f githubactions
```

### Contract testing (Microcks)

`backend` implements the Orders API contract. It can also serve contract-violating responses:

```bash
BACKEND_DRIFT=true  docker compose --profile contract up -d backend    # contract test fails (red)
BACKEND_DRIFT=false docker compose --profile contract up -d backend    # back to green
```

With Podman, `backend` can't be recreated while `krakend` (which depends on it) runs; the talk's walkthrough changes the contract instead. Microcks runs as the all-in-one "uber" image with in-memory storage: imported contracts and test results are gone after a restart and re-imported by CI.

### Backstage catalog

The Backstage app is committed under `governance/api-catalog/` and built in the container (no Node on the host). It serves on port 7007 and reads Gitea with the seeded admin. The Gitea provider scans the `governance-demo` organization for `catalog-info.yaml` and shows the API with its OpenAPI definition and a link to Microcks. The governance repo's `api-guidelines` component carries the guidelines as TechDocs (**Docs** → `api-guidelines`).

The official `@microcks/microcks-backstage-provider` (0.0.7) isn't used: it depends on removed Backstage packages and crashes current Backstage. Microcks is linked from the API entity instead.

### Repository layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | All services, the seed services and the profiles (`contract`, `catalog`, `gateway`). |
| `example/` | The consumer repo template: `contracts/orders-openapi.yaml`, `catalog-info.yaml`, `backend/`, `.gitea/workflows/pr-governance.yml`. |
| `governance/` | `spectral/`, `api-guidelines/`, `gateway/` (generator + `deployer/` sidecar that deploys configs to KrakenD), `api-catalog/` (Backstage). |
| `ci-image/` | The CI job image. |
| `runner-config.yaml` | Puts CI job containers on `gitea-network` and in the CI image. |
| `scripts/` | Seed scripts; `scripts/demo/` is the `demo` helper. |
| `presentation/` | The talk deck and the presenters' material ([`presentation/README.md`](presentation/README.md)). |
| `docs/`, `tests/` | Design notes and scripted PR scenarios. |
| `gitea-data/`, `runner-data/` | Local runtime state, git-ignored, disposable. |

---

## Troubleshooting

**Both engines**
- **A port is already in use:** another service (or another copy of this stack) uses 3000, 2222, 7007, 8080, 8081 or 8090. Stop it, then `up` again.
- **Changes you made in Gitea's `main` disappeared:** every `up` runs `gitea-seed`, which force-pushes `example/` over the consumer repo's `main`. If you use `demo`, run `demo goto <step>` after `up`.
- **Backstage doesn't list the API yet:** wait ~10 s after the merge and reload; `demo refresh-catalog` forces a rescan.
- **A CI job fails before any step ran:** the runner couldn't start the job container. Check `docker logs gitea-runner` / `podman logs gitea-runner`, then use **Re-run** on the run page.

**Docker**
- **Docker Desktop:** give it ~6 GB of memory; the Backstage build can fail with less.
- **Apple Silicon:** all images are available for arm64, and the CI image installs arm64 tools.

**Podman**
- **`gitea-seed` fails or the runner never registers:** the socket isn't reachable. Check `systemctl --user status podman.socket` and that `.env` holds your user id (`id -u`) in `DOCKER_SOCK`.
- **Restarting `backstage` or `gitea-runner` wipes your Gitea `main`:** Podman starts their dependency `gitea-seed` again (Docker doesn't). With `demo`, run `demo goto <step>` afterwards.
- **`backend` can't be recreated** while `krakend` runs ("has dependent containers").

## Stop / reset

```bash
docker compose --profile contract --profile catalog --profile gateway down       # stop
docker compose --profile contract --profile catalog --profile gateway down -v    # + drop the seeded volumes
rm -rf gitea-data runner-data                                                    # + drop Gitea and runner state
```

With Podman, use `podman-compose` with the same arguments, and `podman unshare rm -rf gitea-data runner-data` (the files belong to container users). `demo fresh` does the full wipe and restart in one go.

## Security note

This is a local demo. `gitea-seed`, `gitea-runner` and `krakend-deployer` get access to the container engine socket (to run the Gitea CLI, start CI jobs and restart KrakenD); `krakend-deployer`'s `/deploy` endpoint is unauthenticated on the compose network. Fine on a laptop, not a pattern for shared infrastructure.

## For presenters

The recordings played in the talk, and the tools to make them, are described in [`presentation/README.md`](presentation/README.md).

## Using an AI coding agent

Starter prompt for Claude Code or a similar agent:

> Get familiar with the repo, prepare the environment, and run the tests in `tests/pr-governance.feature.md`. Present a summary as a table with links so I can verify the intermediate states.

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Share and adapt with attribution — see [LICENSE](LICENSE).
