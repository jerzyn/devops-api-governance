# Deck changes: align "DevOps Driven Governance - London 2026" with the demo

What to change in the deck so the slides match the recorded demo (`presentation/screenplay.md`). The deck file itself is not edited here.

**How slides are referenced:** by PDF page (`p30`), checked against the PDF, plus the slide's own label where it has one (`4.2`). The small counter printed on content slides (1–20) skips the pipeline diagrams, so it is not a page number. The "API Governance in the pipeline" diagrams are on `p8`, `p16`, `p19`, `p22`, `p28` and `p33`.

Summary:
- **A.** New step: **API Gateway (KrakenD)**, inserted after Step 3 (Contract Testing) and before Breaking Changes. About 4 new slides plus a pipeline diagram.
- **B.** Breaking Changes becomes **Step 5**, and its example becomes the demo's: a new required query parameter `channel`, reported by oasdiff as `new-required-request-parameter`.
- **C.** Small fixes elsewhere so slide code matches the repo (recommended, not required).

---

## A. New step: API Gateway (KrakenD)

**Where:** between `p28` (the pipeline diagram after Step 3) and `p29` ("Now imagine a partner is integrated"). All pages from `p29` on move back by ~5.

**Story beat:** the contract doesn't stop at the PR. It also drives what runs in production. The gateway config is generated from the contract, validated, deployed, and proven against the same contract test.

### A1. Section title slide (new, same style as `p23`)
- Title: **Expose it — generated from the contract**
- Subtitle: **Step 4 — API Gateway**
- Tagline: *the contract drives the runtime too*

### A2. "Hand-written gateway config drifts" (new, 4.1)
Speaker notes / bullets:
- routes, methods and backends are typed by hand into the gateway, and nobody reviews them against the contract
- the API in the catalog says one thing, the gateway exposes another
- so generate the gateway config from the contract, in CI, on every PR

### A3. "Generated, not written" (new, 4.2)
Code block: the config CI generates from `orders-openapi.yaml`, trimmed.

```json
// krakend.json — generated from the contract by CI
{
  "version": 3,
  "name": "Orders API Gateway",
  "port": 8090,
  "endpoints": [
    {
      "endpoint": "/orders/{orderId}",
      "method": "GET",
      "backend": [
        { "url_pattern": "/orders/{orderId}", "host": ["http://backend:8081"] }
      ]
    }
  ]
}
```
Bullets:
- one endpoint per path + method in the contract, nothing else
- `krakend check` validates it before anything is deployed

### A4. "Deployed — and proven" (new, 4.3)
Terminal block, exactly what the recording shows:

```text
$ curl -i http://localhost:8090/orders/123        # before the PR: no routes
HTTP/1.1 404 Not Found

  ... PR merged: gateway-deploy-check generated, validated, deployed ...

$ curl -i http://localhost:8090/orders/123        # after: through KrakenD
HTTP/1.1 200 OK
{"orderId":"123","isPaid":true}
```
Bullets:
- CI deploys the generated config to the running gateway
- then re-runs the **same Microcks contract test through the gateway**: the gateway must not change what the contract promises
- the gateway's body is byte-for-byte the backend's

### A5. Pipeline diagram (new, copy of `p28` + one box)
Add a box **API Gateway** after **Contract Testing + Mocks**, just before **Deploy**.

### Optional: 4.4 "Contract → gateway: one source of truth"
- the catalog, the tests, the mock and the gateway all come from the same `orders-openapi.yaml`

---

## B. Breaking Changes becomes Step 5, with the demo's example

### B1. `p29` — section title
- `Step 4 — Breaking Changes` → **`Step 5 — Breaking Changes`**
- Renumber the sub-labels `4.x` on `p30`–`p32` to **`5.x`**.

### B2. `p30` — "The innocent change" (5.2)
Replace the YAML block. The demo adds a query parameter to `GET /orders/{orderId}`, not a body property on `POST /orders`: the demo API has no `POST`.

Old:
```yaml
# orders-openapi.yaml — the "innocent" change
Order:
  required:
    - orderId
    - customerId      # ← was optional, now REQUIRED
  ...
```
New:
```yaml
# orders-openapi.yaml — the "innocent" change
paths:
  /orders/{orderId}:
    get:
      parameters:
        - name: orderId
          in: path
          required: true
        - name: channel        # ← new query parameter
          in: query
          required: true       # ← and REQUIRED
```
Speaker notes:
- ~~add currency - safe, additive~~ → **add an optional parameter - safe, additive** (`currency` was already added, as an optional field, in Step 3)
- ~~make customerId required - innocent?~~ → **make it required - innocent?**

### B3. `p31` — oasdiff output (5.3)
Replace the terminal block with the output the demo's CI log shows:

Old:
```text
$ oasdiff breaking  base → PR   (orders-openapi.yaml)
ERROR  request-property-became-required
   POST /orders · request property 'customerId' became required
   clients that omit it today will start getting 400
1 breaking change · exit code 1  →  PR blocked
```
New:
```text
$ oasdiff breaking  origin/main → PR   (contracts/orders-openapi.yaml)
1 changes: 1 error, 0 warning, 0 info
error  [new-required-request-parameter] at contracts/orders-openapi.yaml
       in API GET /orders/{orderId}
       added the new required `query` request parameter `channel`
exit code 1  →  PR blocked  (contract test + gateway: skipped)
```
Title "Blocked - before anyone gets hurt" stays. Speaker notes:
- ~~optional -> required = breaking~~ → **new required parameter = breaking** (clients that don't send `channel` today would get 400)
- ~~quest checkouts/internal tools -> 4xx~~ → **existing partners -> 4xx**
- add: **the later gates (contract test, gateway) don't even run**

### B4. `p32` — "An explicit decision — not an accident" (5.4)
Keep it, and add the demo's resolution as a line or speaker note:
- **fix in the demo: make `channel` optional → all four gates green**
- a truly required parameter means a new major version or a new resource (guideline `rest40`, backward-incompatible changes)

### B5. `p33` — final pipeline diagram
Add the **API Gateway** box (see A5), so the last diagram shows the whole demo.

Left to right, in the order the real pipeline runs (`needs:` chain): **API Guidelines → Breaking Changes → Contract Testing + Mocks → API Gateway → Deploy**.

Breaking Changes is placed *before* contract testing on purpose: a change that breaks clients shouldn't even reach the runtime tests (this is said on camera in Stage 5).

---

## C. Other alignments (recommended)

| Page | Now | Change to | Why |
|---|---|---|---|
| `p12` (1.2) | `name: sample-orders-api`; `owner: platform-team` under `metadata`; `lifecycle: production` | `name: orders-api`; `owner: group:default/platform-team` under **`spec`**; `lifecycle: experimental` | Matches the `catalog-info.yaml` shown on camera. `owner` belongs in `spec` in Backstage. |
| `p18` (2.2) "Guidelines live in the API catalog" | text only | Add a screenshot of the Backstage **API Guidelines** TechDocs page, on the HTTPS rule | The recording now shows it: the Spectral error links straight to the rule in the catalog. |
| `p20` (2.3) "The same rules - as code" | example "operation summary is missing?" | example: **server URL uses `http://` → `api-peak:rest17:2025-https-required`**, with the link to the rule in the catalog | The demo's red check is the HTTPS rule. The link shows the "rule, file, line, how to fix" feedback in one line. |
| `p24`–`p25` (3.2–3.3) mocks | text only | Add the terminal shot from the recording: `curl http://localhost:8080/rest/Orders+API/1.0.0/orders/123` → `{"orderId":"123","isPaid":true,"currency":"PLN"}` | The recording now shows the live mock served from the PR's contract. |
| `p27` (3.5) notes: "+ generic MCP mock from OpenAPI" | mentioned | Keep only as roadmap, or drop | Not built in the repo: nothing on camera shows it. |
| Every pipeline diagram (`p8` … `p33`) | – | Check the box order matches B5 | Consistency with the new last diagram. |
