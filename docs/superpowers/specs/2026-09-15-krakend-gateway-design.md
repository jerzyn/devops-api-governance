# KrakenD API gateway gate — design

Status: approved by user, ready for implementation planning.

## Purpose

Add a fourth step to the PR governance pipeline that closes the DevOps loop
for API governance: expose the API through an actual API management gateway
(KrakenD CE), with the gateway's routing config generated from the same
OpenAPI contract that Spectral lints and Backstage catalogs. This makes the
demo's existing chain — **documented → discovered → delivered** — end in a
real, runnable gateway, not just a catalog entry.

## Scope decision: functional gateway, blocking gate

Two options were considered: a "config-publishing artifact" (CI just
generates/pushes config, no live routing needed) vs a functional gateway
(KrakenD actually routes traffic to `sample-backend`, demoable live). The
user chose **functional gateway**, and further, chose to make it a **fourth
blocking PR gate** (not a post-merge step like Backstage catalog discovery) —
consistent with how `contract-test` already treats "does the PR's actual
artifact work against a live dependency" as gate material, not an
after-the-fact concern.

## Pipeline order (and why)

```
spectral-openapi-check → breaking-changes-check → contract-test → gateway-deploy-check
```

`gateway-deploy-check` runs **last**, gated on `contract-test` passing.
Rationale, explicitly asked and settled during design: `contract-test`
answers "does the backend implement the contract correctly" — an
implementation-correctness question, independent of how the API is exposed.
`gateway-deploy-check` answers a different question — "does the gateway
correctly expose what has already been proven correct" — and doing it last
means a contract/backend that hasn't already passed `contract-test` never
gets a gateway deployed for it. This mirrors the repository's own existing
rationale for `breaking-changes-check → contract-test` ordering (documented
in `docs/ci-fixes-scope.md`): don't spend the next gate's cost on something
that's already going to be rejected.

## Config generation: OpenAPI is the only source of truth

The OpenAPI contract (`contracts/orders-openapi.yaml`) is generated into a
KrakenD config (`krakend.json`) by a script — **no second, hand-maintained
gateway config file**. Keeping the contract as the sole source of truth is
the same principle already applied everywhere else in this repo (Spectral
lints it, Microcks mocks/tests from it, Backstage catalogs it).

The generator walks the contract's `paths`, and for each operation emits a
KrakenD endpoint entry:
- `endpoint`: the OpenAPI path (KrakenD uses `{var}` path params the same as
  OpenAPI, no translation needed for this contract's shape)
- `method`: the HTTP method
- `backend[0].url_pattern`: the same path
- `backend[0].host`: `["http://sample-backend:8081"]`

Out of scope for v1 (YAGNI, revisit only if a second API ever joins this
demo): request/response transformation, auth, rate-limiting, and multi-service
aggregation. KrakenD's own "flexible config" (per-service partial files
merged at startup) is the natural extension point if/when a second consumer
API needs to join the same gateway — not built now because there is only one
API in this demo.

## Location: `governance/gateway/`, linked not vendored

The generator (Node.js, matching the existing `governance/spectral/spectral-functions/`
tooling style) and KrakenD's base config template live in
`governance/gateway/`, following the exact pattern already established for
the Spectral ruleset: single source of truth in the governance context,
cloned by the consumer's CI at run time rather than vendored into the
consumer repo. `scripts/seed-gitea.sh`'s lean governance-repo push (currently
copying `spectral/` and `api-guidelines/`) is extended to also copy
`gateway/` into the seeded `governance-demo/api-governance` repo, so the
consumer CI can clone it the same way it already clones the ruleset.

## Deploy mechanism: why a sidecar

KrakenD CE has no hot-reload or admin API (those are Enterprise features) —
picking up a new config requires restarting the KrakenD process/container.
The repo's PR-governance job containers were deliberately stripped of
docker/podman socket access in a prior fix (`runner-config.yaml`'s
`container.docker_host: "-"`, closing a real bug where act_runner mounted
the host socket into every job container by default even though no job
needed it). A gate that needs to restart a container is a genuinely new
requirement this fix didn't anticipate, and act_runner's `docker_host`
setting is runner-wide, not per-job — so job containers cannot regain
selective docker access without undoing that fix for every job.

Rather than reverting the least-privilege fix, introduce **`krakend-deployer`**:
a small sidecar container (mounts the docker/podman socket, same pattern as
`gitea-seed`/`gitea-runner`) exposing one HTTP endpoint, `POST /deploy`. The
CI job — network-reachable via `gitea-network`, no socket needed — POSTs the
generated `krakend.json` to it; the sidecar writes it to a shared volume and
restarts the `krakend` container. This is architecturally identical to the
existing `seed-microcks.sh` pattern (a small HTTP-reachable helper doing
work a job container can't do directly), just repurposed for a container
restart instead of a REST import call.

## `gateway-deploy-check` job steps

No changed-files skip check: like `contract-test` (which has no such skip
today and always re-imports/re-tests once reached), `gateway-deploy-check`
always runs once it's reached — regenerating and redeploying the same
config when the contract didn't change is a cheap no-op, and matching
`contract-test`'s existing posture keeps the two "runs against a live
dependency" gates consistent with each other.

1. Checkout PR branch.
2. Clone `governance-demo/api-governance` (already done by
   `spectral-openapi-check`; this job clones it independently, same as
   `breaking-changes-check` and `contract-test` each do their own checkout).
3. Run the generator against the PR's `contracts/orders-openapi.yaml` →
   `krakend.json`.
4. `krakend check -c krakend.json` — offline validation. Fail the gate on any
   error (same posture as `oasdiff`/Spectral: a real lint, not a soft check).
5. `POST` the validated config to `krakend-deployer`'s `/deploy` endpoint;
   it writes the config and restarts the `krakend` container.
6. Wait for KrakenD to be ready (same poll-with-timeout pattern
   `contract-test` already uses for Microcks).
7. **Re-run the full Microcks test suite** against the gateway instead of the
   backend directly: same `serviceId` already imported by `contract-test`,
   but `testEndpoint=http://krakend:8090` instead of
   `http://sample-backend:8081`. This was an explicit refinement during
   design — a single smoke-test request was considered and rejected in favor
   of reusing the full existing contract-test suite, since it catches
   gateway-specific bugs (bad path rewriting, dropped headers, wrong method
   mapping) that a single manual request would likely miss. Mechanically
   this step is almost identical to `contract-test`'s existing "Run contract
   test" step, just pointed at a different endpoint — no new test-writing,
   just a parameterized re-run.
8. Fail the gate on any test failure.

## Docker Compose changes

New `profiles: ["gateway"]` (a new profile, not folded into `contract`,
consistent with the existing one-profile-per-capability pattern):

- `krakend` — image `krakend/krakend:latest`, port `8090`, config volume
  shared with `krakend-deployer`, `depends_on: sample-backend`.
- `krakend-deployer` — the sidecar described above; mounts the docker/podman
  socket and the same shared config volume; no published port (only
  reachable from job containers via `gitea-network`).

Full demo becomes:
`docker compose --profile contract --profile catalog --profile gateway up -d`

## Explicitly out of scope (YAGNI)

- Multi-API / multi-service gateway aggregation (single API in this demo;
  KrakenD flexible-config partials are the extension point if this changes).
- Auth, rate-limiting, or any other gateway middleware.
- Concurrent-PR isolation for the shared `krakend`/`krakend-deployer`
  instance — same single-tenant local-demo scope already accepted for
  Microcks (`contract-test` has the identical limitation today).
- Reverting or narrowing the `docker_host: "-"` fix for any job other than
  `gateway-deploy-check`'s use of the sidecar's HTTP API (the job itself
  never gets socket access).
