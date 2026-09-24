# CI design decisions

Five specific design choices in
[`example/.gitea/workflows/pr-governance.yml`](../example/.gitea/workflows/pr-governance.yml),
each already commented inline where it's made — this page just collects the
"why" in one place instead of leaving it scattered across the workflow.

## Linked ruleset, not vendored

`spectral-openapi-check` clones `governance-demo/api-governance` at run time
rather than carrying a copy of the ruleset in the consumer repo. Rationale
and tradeoff: [`demo-isolation.md`](demo-isolation.md).

## Ordering via `needs:`

Each job in the pipeline (see [`ci-test-path.md`](ci-test-path.md) for the
actual sequence) is gated by `needs:` on the previous one. A contract that
fails lint or breaks existing clients never gets a runtime contract test —
there's no point testing something that's already going to be rejected.

## Report URL: public vs internal host

Contract-test results are launched and polled against `MICROCKS_URL`
(`http://microcks-uber:8080`, the internal Docker-network hostname CI job
containers use). But the human-facing link printed to the CI log uses
`MICROCKS_PUBLIC_URL` (`http://localhost:8080`) instead — the internal
hostname isn't resolvable from a browser on the host.

## PR-branch contract, not main's

`contract-test` checks out the PR head commit (`github.event.pull_request.head.sha`),
not the base branch, and imports *that* contract into Microcks. Testing
main's already-merged contract instead would validate the wrong version
entirely once a PR is mid-review.

## Version-derive, not hardcoded

The Microcks `serviceId` needs a version (`"Orders API:1.0.0"`, say).
Instead of hardcoding that version, the workflow reads it out of the
checked-out contract's `info.version` at run time. A PR that bumps the
version doesn't silently start testing against a stale, nonexistent service
id.

## Gateway deploy: a sidecar, not docker-in-job

`gateway-deploy-check` needs to restart the `krakend` container to pick up
a new config (KrakenD CE has no hot-reload or admin API). Job containers
were deliberately stripped of docker/podman socket access in an earlier
fix (`runner-config.yaml`'s `container.docker_host: "-"`) because none of
the other three jobs need it, and that setting is runner-wide, not
per-job. Rather than reverting that fix, `krakend-deployer` — a small
sidecar with socket access, mirroring the existing `gitea-seed`/
`gitea-runner` mount pattern — exposes one HTTP endpoint the job container
calls instead.
