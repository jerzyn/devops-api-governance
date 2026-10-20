# ADR 0001: Governance for MCP servers

- **Status:** Proposed
- **Date:** 2026-10-20
- **Scope:** extends this demo's REST APIOps pipeline to MCP servers. No code yet; this record fixes the decisions the implementation builds on.

## Context

An MCP server is a contract too: its tools (with `inputSchema` and `outputSchema`), resources, resource templates and prompts. Unlike an OpenAPI file, that contract is published at runtime (`tools/list`, `resources/list`, `prompts/list`), not in a spec file.

The REST side of this repo already runs four PR gates in order (Spectral → oasdiff → Microcks contract test → KrakenD deploy), with Backstage as the catalog and the "linked, not vendored" two-repo model ([`demo-isolation.md`](../demo-isolation.md)). MCP governance should reuse that shape and as much of that tooling as fits, so one team can run both.

## Decisions

1. **Code-first with a committed manifest snapshot.** The MCP server is the source of truth. A snapshot script calls `initialize`, `tools/list`, `resources/list`, `resources/templates/list` and `prompts/list`, normalizes the result (pagination via `nextCursor`, sorted by `name`/`uri`, stable keys, no runtime-varying fields) and writes `contracts/<name>.mcp.json`. The committed file is the artifact under review. A `mcp-manifest-drift-check` gate regenerates it in CI and fails on `git diff --exit-code`. This is the opposite of the REST side's contract-first approach, and the guidelines say so explicitly.

2. **Same two-repo model.** Rules, generators and the test runner live under `governance/mcp/` (and `governance/spectral/mcp-ruleset.yaml`), linked at CI time. A new consumer template `example-mcp/` holds the example server, its manifest, examples and `catalog-info.yaml`.

3. **Same gates, same order.** `mcp-manifest-drift-check` → `spectral-mcp-check` → `mcp-breaking-changes-check` → `mcp-contract-test` → `mcp-gateway-deploy-check`, each gated by `needs:`. The catalog updates on merge, as today.

4. **Reuse the existing tools where they fit.**
   - *Lint:* Spectral with a separate `mcp-ruleset.yaml` (no `extends: spectral:oas`), custom JS functions and JSON Schema meta-validation. Rules are documented in the existing API guidelines TechDocs (new `mcp.md` page) and every finding links to its rule.
   - *Breaking changes:* an adapter turns the manifest into a synthetic OpenAPI document (tool → `POST /tools/{name}`, `inputSchema` → request body, `outputSchema` → 200 response), so the pinned oasdiff with `--fail-on ERR` checks the schemas. A small structural diff covers the rest: removed or renamed tools, prompts and resource templates; new required prompt arguments; `readOnlyHint` true→false or `destructiveHint` false→true. Description changes are reported for review, since a tool description is part of the model's prompt.
   - *Catalog:* Backstage `kind: API` with `spec.type: mcp-server` and the manifest as `definition`.

5. **New tooling only where MCP needs it.** Microcks and KrakenD don't speak MCP JSON-RPC, so the path in front of the MCP server gets:
   - a contract-test runner on `@modelcontextprotocol/sdk` that calls each tool with examples from `contracts/<name>.mcp.examples.yaml` and validates `structuredContent` against `outputSchema` (destructive tools only against the test backend);
   - an MCP proxy whose policy (tool allowlist, a hash of each tool's definition, roles by `annotations`) is generated from the approved manifest. A tool missing from the approved manifest is not visible through the proxy. The proxy implementation is chosen after a spike; the demo can use a small Node proxy in the style of `krakend-deployer`.

6. **Language and transport.** Node/TypeScript (the CI image and `governance/gateway` are already Node 20), Streamable HTTP in Compose.

7. **The example MCP server is curated, not generated 1:1 from OpenAPI.** A generator from `orders-openapi.yaml` may be used only as a scaffold, limited to an allowlist of `operationId`s. Names, LLM-facing descriptions, `annotations` and `outputSchema` are written by hand, and tools are task-shaped (`get_order`, `list_orders`, `cancel_order`), not CRUD. The server calls the Orders API through KrakenD, so the existing REST gates keep covering it, and a breaking OpenAPI change also triggers the MCP contract test. A 1:1 generated server is a good "red" example for the MCP lint gate (tool count, weak descriptions, missing annotations).

## Consequences

- One snapshot file feeds every MCP gate, the same way `contracts/orders-openapi.yaml` feeds the REST gates.
- The CI image gains the MCP SDK and ajv; Compose gains an `mcp` profile; `gitea-seed` seeds a third repo for the example MCP server.
- Servers whose `tools/list` depends on user, feature flags or `listChanged` are snapshotted with a fixed identity and must declare it in `catalog-info.yaml`.
- `outputSchema` is optional in MCP, so the rule requiring it starts as a warning.
- oasdiff messages speak of request bodies, not tool arguments; the MCP diff step rewrites them before annotating the PR.
- The breaking-change gate stays as strict as the REST one: bumping `serverInfo.version` alone does not clear it.

## Open questions

- Minimum MCP protocol version the lint gate requires.
- Which MCP gateway/proxy to use beyond the demo.
- Whether this becomes demo stages under `scripts/demo/` or a separate track for real servers.
