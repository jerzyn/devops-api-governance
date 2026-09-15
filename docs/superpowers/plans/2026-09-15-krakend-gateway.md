# KrakenD API Gateway Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth, blocking PR-governance gate that generates a KrakenD CE gateway config from the OpenAPI contract, deploys it to a running KrakenD instance, and re-runs the Microcks contract-test suite through the gateway.

**Architecture:** A pure-logic generator (`governance/gateway/generate.js`, no infra dependency) turns the contract into `krakend.json`. A tiny sidecar (`krakend-deployer`) with docker/podman socket access receives that config over HTTP and restarts the `krakend` container, so the CI job container itself never needs socket access (preserves the existing `docker_host: "-"` least-privilege fix). The new job is inserted after `contract-test` in `example/.gitea/workflows/pr-governance.yml`.

**Tech Stack:** Node.js (built-in `node --test` runner, no new test framework), `js-yaml` (only new npm dependency, for the generator), KrakenD CE (`krakend/krakend` Docker image), the existing Gitea Actions / act_runner / Microcks stack.

**Spec:** `docs/superpowers/specs/2026-09-15-krakend-gateway-design.md`

## Global Constraints

- Config generation reads only `contracts/orders-openapi.yaml`; no second, hand-maintained gateway config file (spec: "Config generation").
- Generator and KrakenD base config live in `governance/gateway/`, cloned by consumer CI at run time — never vendored into `example/` (spec: "Location").
- Job containers never regain docker/podman socket access; only `krakend-deployer` (a dedicated sidecar) has it (spec: "Deploy mechanism").
- `gateway-deploy-check` runs after `contract-test` (`needs: contract-test`), last in the gate chain (spec: "Pipeline order").
- Gate 4's final check re-runs the full Microcks test suite against the gateway endpoint (`http://krakend:8090`), not a one-off smoke request (spec: step 7).
- New Docker Compose services join a new `gateway` profile, not `contract` (spec: "Docker Compose changes").
- Out of scope: multi-service aggregation, gateway auth/rate-limiting, concurrent-PR isolation (spec: "Explicitly out of scope").

---

### Task 1: OpenAPI → KrakenD config generator

**Files:**
- Create: `governance/gateway/package.json`
- Create: `governance/gateway/krakend-base.json`
- Create: `governance/gateway/generate.js`
- Create: `governance/gateway/generate.test.js`
- Modify: `.gitignore` (append `governance/gateway/node_modules/`)

**Interfaces:**
- Produces: `governance/gateway/generate.js` exports `{ buildEndpoints(contract, backendHost), generate(contractPath, basePath, backendHost) }`. `buildEndpoints` takes a parsed OpenAPI object and a backend base URL string, returns an array of KrakenD endpoint objects. `generate` takes a contract file path, a base-config file path, and a backend base URL string, returns the full merged KrakenD config object. Running the file directly (`node generate.js <contract.yaml> <output.json> [backendHost]`) writes the generated config to disk.

- [ ] **Step 1: Write `governance/gateway/package.json`**

```json
{
  "name": "governance-gateway-tools",
  "private": true,
  "version": "1.0.0",
  "description": "OpenAPI-to-KrakenD config generator (linked governance tooling, cloned by consumer CI)",
  "main": "generate.js",
  "scripts": {
    "test": "node --test generate.test.js"
  },
  "dependencies": {
    "js-yaml": "^4.1.0"
  }
}
```

- [ ] **Step 2: Write `governance/gateway/krakend-base.json`**

```json
{
  "version": 3,
  "name": "Sample Orders API Gateway",
  "port": 8090,
  "timeout": "5s",
  "cache_ttl": "0s",
  "output_encoding": "json",
  "endpoints": []
}
```

- [ ] **Step 3: Append to `.gitignore`**

Add this block after the existing `.lurus/` entry:

```
# Gateway generator's npm install (linked tooling, installed fresh by CI
# and by local development - never commit the resolved tree)
governance/gateway/node_modules/
```

- [ ] **Step 4: Install the generator's dependency locally, to run tests**

```bash
cd governance/gateway && npm install
```

Expected: `node_modules/js-yaml` exists; no errors.

- [ ] **Step 5: Write the failing test file `governance/gateway/generate.test.js`**

```js
'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { buildEndpoints, generate } = require('./generate');

test('buildEndpoints emits one entry per operation, uppercase method, matching backend url_pattern', () => {
  const contract = {
    paths: {
      '/orders/{orderId}': {
        summary: 'Orders resource',
        get: { summary: 'Get order', operationId: 'getOrder' },
      },
    },
  };
  const endpoints = buildEndpoints(contract, 'http://sample-backend:8081');
  assert.equal(endpoints.length, 1);
  assert.deepEqual(endpoints[0], {
    endpoint: '/orders/{orderId}',
    method: 'GET',
    backend: [
      {
        url_pattern: '/orders/{orderId}',
        method: 'GET',
        host: ['http://sample-backend:8081'],
      },
    ],
  });
});

test('buildEndpoints emits multiple entries for multiple methods on the same path', () => {
  const contract = {
    paths: {
      '/orders': {
        get: { summary: 'List orders' },
        post: { summary: 'Create order' },
      },
    },
  };
  const endpoints = buildEndpoints(contract, 'http://sample-backend:8081');
  assert.equal(endpoints.length, 2);
  assert.deepEqual(endpoints.map((e) => e.method).sort(), ['GET', 'POST']);
});

test('buildEndpoints ignores non-method path-item keys (summary, description, parameters)', () => {
  const contract = {
    paths: {
      '/orders/{orderId}': {
        summary: 'Orders resource',
        description: 'blah',
        parameters: [{ name: 'orderId', in: 'path' }],
        get: { summary: 'Get order' },
      },
    },
  };
  const endpoints = buildEndpoints(contract, 'http://sample-backend:8081');
  assert.equal(endpoints.length, 1);
  assert.equal(endpoints[0].method, 'GET');
});

test('buildEndpoints returns an empty array for a contract with no paths', () => {
  const endpoints = buildEndpoints({ paths: {} }, 'http://sample-backend:8081');
  assert.deepEqual(endpoints, []);
});

test('generate merges endpoints into the base config, preserving base fields', () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'krakend-gen-'));
  const contractPath = path.join(tmpDir, 'contract.yaml');
  const basePath = path.join(tmpDir, 'base.json');
  fs.writeFileSync(
    contractPath,
    ['paths:', '  /health:', '    get:', '      summary: Health check'].join('\n')
  );
  fs.writeFileSync(basePath, JSON.stringify({ version: 3, name: 'Test Gateway', port: 8090 }));

  const config = generate(contractPath, basePath, 'http://sample-backend:8081');

  assert.equal(config.version, 3);
  assert.equal(config.name, 'Test Gateway');
  assert.equal(config.port, 8090);
  assert.equal(config.endpoints.length, 1);
  assert.equal(config.endpoints[0].endpoint, '/health');
});
```

- [ ] **Step 6: Run the tests to verify they fail**

```bash
cd governance/gateway && node --test generate.test.js
```

Expected: FAIL — `Cannot find module './generate'` (the file doesn't exist yet).

- [ ] **Step 7: Write `governance/gateway/generate.js`**

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const VALID_METHODS = new Set([
  'get',
  'put',
  'post',
  'delete',
  'patch',
  'head',
  'options',
  'trace',
]);

function loadContract(contractPath) {
  const raw = fs.readFileSync(contractPath, 'utf8');
  return yaml.load(raw);
}

function loadBaseConfig(basePath) {
  const raw = fs.readFileSync(basePath, 'utf8');
  return JSON.parse(raw);
}

function buildEndpoints(contract, backendHost) {
  const endpoints = [];
  const paths = (contract && contract.paths) || {};
  for (const [pathKey, pathItem] of Object.entries(paths)) {
    for (const [method, operation] of Object.entries(pathItem || {})) {
      if (!VALID_METHODS.has(method)) continue;
      if (!operation || typeof operation !== 'object') continue;
      endpoints.push({
        endpoint: pathKey,
        method: method.toUpperCase(),
        backend: [
          {
            url_pattern: pathKey,
            method: method.toUpperCase(),
            host: [backendHost],
          },
        ],
      });
    }
  }
  return endpoints;
}

function generate(contractPath, basePath, backendHost) {
  const contract = loadContract(contractPath);
  const base = loadBaseConfig(basePath);
  const endpoints = buildEndpoints(contract, backendHost);
  return { ...base, endpoints };
}

function main() {
  const [, , contractPath, outputPath, backendHostArg] = process.argv;
  if (!contractPath || !outputPath) {
    console.error('Usage: node generate.js <contract.yaml> <output.json> [backendHost]');
    process.exit(1);
  }
  const backendHost = backendHostArg || 'http://sample-backend:8081';
  const basePath = path.join(__dirname, 'krakend-base.json');
  const config = generate(contractPath, basePath, backendHost);
  fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
  console.log(`Wrote ${outputPath} with ${config.endpoints.length} endpoint(s).`);
}

if (require.main === module) {
  main();
}

module.exports = { buildEndpoints, generate };
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
cd governance/gateway && node --test generate.test.js
```

Expected: PASS — 5 tests, 0 failures.

- [ ] **Step 9: Manual smoke test against the real contract**

```bash
cd governance/gateway && node generate.js ../../example/contracts/orders-openapi.yaml /tmp/krakend-smoke.json
cat /tmp/krakend-smoke.json
```

Expected: valid JSON, `endpoints` array has exactly one entry for `GET /orders/{orderId}` with `host: ["http://sample-backend:8081"]`. Delete `/tmp/krakend-smoke.json` afterward.

- [ ] **Step 10: Commit**

```bash
git add governance/gateway/package.json governance/gateway/krakend-base.json \
  governance/gateway/generate.js governance/gateway/generate.test.js .gitignore
git commit -m "feat: add OpenAPI-to-KrakenD config generator

Pure-logic, TDD-covered generator turning contracts/orders-openapi.yaml
into a KrakenD endpoint list, merged into a base config. No infra
dependency - unit tested with node --test, no new test framework."
```

---

### Task 2: `krakend-deployer` sidecar HTTP server

**Files:**
- Create: `governance/gateway/deployer/server.js`
- Create: `governance/gateway/deployer/server.test.js`

**Interfaces:**
- Consumes: nothing from Task 1 (independent component).
- Produces: `governance/gateway/deployer/server.js` exports `{ server }` (a `node:http` server instance, not yet listening on import). Reads config from env vars `PORT` (default `9000`), `CONFIG_PATH` (default `/shared/krakend.json`), `KRAKEND_CONTAINER` (default `krakend`), `CONTAINER_ENGINE` (default `docker`). Routes: `POST /deploy` (body: KrakenD JSON config; writes it to `CONFIG_PATH`, then runs `${CONTAINER_ENGINE} restart ${KRAKEND_CONTAINER}`), `GET /health` (returns `{"status":"ok"}`).

- [ ] **Step 1: Write the failing test file `governance/gateway/deployer/server.test.js`**

```js
'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');

function freshServer(env) {
  Object.assign(process.env, env);
  delete require.cache[require.resolve('./server')];
  return require('./server').server;
}

function listen(server) {
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve(server.address().port));
  });
}

function request(port, options, body) {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, ...options }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () =>
        resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString('utf8') })
      );
    });
    req.on('error', reject);
    if (body !== undefined) req.write(body);
    req.end();
  });
}

test('POST /deploy writes the config and invokes the restart command', async () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'krakend-deployer-'));
  const configPath = path.join(tmpDir, 'krakend.json');
  const markerPath = path.join(tmpDir, 'restarted.marker');
  const stubEnginePath = path.join(tmpDir, 'fake-engine.sh');
  fs.writeFileSync(stubEnginePath, `#!/bin/sh\ntouch "${markerPath}"\nexit 0\n`);
  fs.chmodSync(stubEnginePath, 0o755);

  const server = freshServer({
    CONFIG_PATH: configPath,
    CONTAINER_ENGINE: stubEnginePath,
    KRAKEND_CONTAINER: 'krakend',
  });
  const port = await listen(server);

  const payload = JSON.stringify({ version: 3, endpoints: [] });
  const result = await request(
    port,
    { method: 'POST', path: '/deploy', headers: { 'Content-Type': 'application/json' } },
    payload
  );

  server.close();

  assert.equal(result.status, 200);
  assert.deepEqual(JSON.parse(result.body), { status: 'deployed' });
  assert.equal(fs.readFileSync(configPath, 'utf8'), JSON.stringify(JSON.parse(payload), null, 2));
  assert.equal(fs.existsSync(markerPath), true);
});

test('POST /deploy with invalid JSON body returns 400 and does not write the config', async () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'krakend-deployer-'));
  const configPath = path.join(tmpDir, 'krakend.json');

  const server = freshServer({ CONFIG_PATH: configPath, CONTAINER_ENGINE: 'true' });
  const port = await listen(server);

  const result = await request(port, { method: 'POST', path: '/deploy' }, 'not json');

  server.close();

  assert.equal(result.status, 400);
  assert.equal(fs.existsSync(configPath), false);
});

test('POST /deploy returns 502 when the restart command fails', async () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'krakend-deployer-'));
  const configPath = path.join(tmpDir, 'krakend.json');
  const failingEnginePath = path.join(tmpDir, 'failing-engine.sh');
  fs.writeFileSync(failingEnginePath, '#!/bin/sh\necho "boom" >&2\nexit 1\n');
  fs.chmodSync(failingEnginePath, 0o755);

  const server = freshServer({ CONFIG_PATH: configPath, CONTAINER_ENGINE: failingEnginePath });
  const port = await listen(server);

  const result = await request(
    port,
    { method: 'POST', path: '/deploy', headers: { 'Content-Type': 'application/json' } },
    JSON.stringify({ version: 3 })
  );

  server.close();

  assert.equal(result.status, 502);
});

test('GET /health returns 200 and status ok', async () => {
  const server = freshServer({});
  const port = await listen(server);

  const result = await request(port, { method: 'GET', path: '/health' });

  server.close();

  assert.equal(result.status, 200);
  assert.deepEqual(JSON.parse(result.body), { status: 'ok' });
});

test('ensureInitialConfig writes a default config only if none exists', () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'krakend-deployer-'));
  const configPath = path.join(tmpDir, 'nested', 'krakend.json');

  const { ensureInitialConfig } = freshServerModule({ CONFIG_PATH: configPath });
  ensureInitialConfig();
  assert.equal(fs.existsSync(configPath), true);
  const firstWrite = fs.readFileSync(configPath, 'utf8');

  fs.writeFileSync(configPath, '{"custom":true}');
  ensureInitialConfig();
  assert.equal(fs.readFileSync(configPath, 'utf8'), '{"custom":true}');
  assert.notEqual(firstWrite, '{"custom":true}');
});

function freshServerModule(env) {
  Object.assign(process.env, env);
  delete require.cache[require.resolve('./server')];
  return require('./server');
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd governance/gateway/deployer && node --test server.test.js
```

Expected: FAIL — `Cannot find module './server'`.

- [ ] **Step 3: Write `governance/gateway/deployer/server.js`**

```js
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');

const PORT = Number(process.env.PORT) || 9000;
const CONFIG_PATH = process.env.CONFIG_PATH || '/shared/krakend.json';
const CONTAINER_NAME = process.env.KRAKEND_CONTAINER || 'krakend';
const CONTAINER_ENGINE = process.env.CONTAINER_ENGINE || 'docker';

const DEFAULT_CONFIG = {
  version: 3,
  name: 'Sample Orders API Gateway (uninitialized)',
  port: 8090,
  timeout: '5s',
  cache_ttl: '0s',
  output_encoding: 'json',
  endpoints: [],
};

function ensureInitialConfig() {
  if (!fs.existsSync(CONFIG_PATH)) {
    fs.mkdirSync(path.dirname(CONFIG_PATH), { recursive: true });
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(DEFAULT_CONFIG, null, 2));
  }
}

function restartKrakend(callback) {
  execFile(CONTAINER_ENGINE, ['restart', CONTAINER_NAME], (error, stdout, stderr) => {
    callback(error, stdout, stderr);
  });
}

function readBody(req, callback) {
  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => callback(Buffer.concat(chunks).toString('utf8')));
  req.on('error', (err) => callback(null, err));
}

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(payload);
}

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/deploy') {
    readBody(req, (body, readErr) => {
      if (readErr) {
        return sendJson(res, 400, { error: 'failed to read request body' });
      }
      let parsed;
      try {
        parsed = JSON.parse(body);
      } catch (e) {
        return sendJson(res, 400, { error: 'body is not valid JSON' });
      }
      fs.mkdir(path.dirname(CONFIG_PATH), { recursive: true }, (mkdirErr) => {
        if (mkdirErr) {
          return sendJson(res, 500, { error: `failed to create config dir: ${mkdirErr.message}` });
        }
        fs.writeFile(CONFIG_PATH, JSON.stringify(parsed, null, 2), (writeErr) => {
          if (writeErr) {
            return sendJson(res, 500, { error: `failed to write config: ${writeErr.message}` });
          }
          restartKrakend((restartErr, stdout, stderr) => {
            if (restartErr) {
              return sendJson(res, 502, {
                error: `failed to restart krakend: ${stderr || restartErr.message}`,
              });
            }
            sendJson(res, 200, { status: 'deployed' });
          });
        });
      });
    });
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    return sendJson(res, 200, { status: 'ok' });
  }

  sendJson(res, 404, { error: 'not found' });
});

if (require.main === module) {
  ensureInitialConfig();
  server.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`krakend-deployer listening on :${PORT}, config at ${CONFIG_PATH}`);
  });
}

module.exports = { server, ensureInitialConfig };
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd governance/gateway/deployer && node --test server.test.js
```

Expected: PASS — 6 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add governance/gateway/deployer/server.js governance/gateway/deployer/server.test.js
git commit -m "feat: add krakend-deployer sidecar HTTP server

Small dependency-free HTTP server: POST /deploy writes a config and
restarts the krakend container via a configurable container engine
binary, GET /health for readiness polling. Exists so job containers
never need docker/podman socket access - only this sidecar does,
mirroring gitea-seed/gitea-runner's existing socket-mount pattern.
Restart invocation is unit-tested against a stub engine script, no
real Docker/Podman needed to run these tests."
```

---

### Task 3: `krakend` + `krakend-deployer` Docker Compose services

**Files:**
- Create: `governance/gateway/deployer/Dockerfile`
- Modify: `docker-compose.yml` (append two services + one volume, after the existing "Track B: contract testing" block and before "Track A: catalog", or after catalog — placement doesn't matter functionally; append as a new "Track C: gateway" block after the catalog block)

**Interfaces:**
- Consumes: Task 2's `governance/gateway/deployer/server.js` (built into the deployer image).
- Produces: two running services reachable on `gitea-network` as `krakend:8090` (host-published too, `localhost:8090`) and `krakend-deployer:9000` (not host-published — only job containers need it).

- [ ] **Step 1: Write `governance/gateway/deployer/Dockerfile`**

```dockerfile
# Same base image family as gitea-seed (docker:27-cli) for a trusted,
# already-used-in-this-repo docker/podman CLI, plus Node for server.js.
FROM docker:27-cli
RUN apk add --no-cache nodejs
WORKDIR /app
COPY server.js .
ENV PORT=9000
ENV CONFIG_PATH=/shared/krakend.json
ENV KRAKEND_CONTAINER=krakend
ENV CONTAINER_ENGINE=docker
EXPOSE 9000
CMD ["node", "server.js"]
```

- [ ] **Step 2: Read the current end of `docker-compose.yml`**

Find the closing of the `backstage` service block (the last service before the top-level `volumes:` key) to append after it.

- [ ] **Step 3: Append the new services to `docker-compose.yml`**

Insert this block after the `backstage` service and before the top-level `volumes:` key:

```yaml
  # --- Track C: API gateway (profile: gateway) --------------------------------
  # KrakenD CE - real gateway routing to sample-backend. Config is generated
  # from the OpenAPI contract by governance/gateway/generate.js and deployed
  # via krakend-deployer: KrakenD CE has no hot-reload/admin API, and job
  # containers were deliberately stripped of docker/podman socket access
  # (see runner-config.yaml's container.docker_host) - so a small sidecar
  # with socket access does the restart instead of the job container.
  krakend:
    image: krakend/krakend:latest
    container_name: krakend
    restart: unless-stopped
    profiles: ["gateway"]
    depends_on:
      - sample-backend
    volumes:
      - krakend-config:/etc/krakend
    command: ["run", "-c", "/etc/krakend/krakend.json"]
    ports:
      - "8090:8090"

  krakend-deployer:
    build: ./governance/gateway/deployer
    container_name: krakend-deployer
    restart: unless-stopped
    profiles: ["gateway"]
    volumes:
      - krakend-config:/shared
      - /var/run/docker.sock:/var/run/docker.sock
```

- [ ] **Step 4: Add the new named volume**

In the top-level `volumes:` key (currently just `seed-state:`), add `krakend-config:` as a sibling:

```yaml
volumes:
  seed-state:
  krakend-config:
```

- [ ] **Step 5: Manual verification — build and bring up the gateway profile**

No unit-test seam here (Docker/Compose infra); verify manually, same as this repo's other infra pieces.

```bash
docker compose --profile contract --profile gateway up -d --build
```

Expected: `krakend` and `krakend-deployer` containers start; `krakend-deployer` logs `krakend-deployer listening on :9000, config at /shared/krakend.json`; `krakend` logs show it started (it will run with the deployer's bootstrapped empty-endpoints default config, since nothing has deployed to it yet).

- [ ] **Step 6: Manual verification — health check and a real deploy round-trip**

```bash
curl -sf http://localhost:8090  # KrakenD responds (404/empty routing is fine - it's up)

# krakend-deployer has no host-published port by design (spec: only job
# containers need to reach it) - hit it from a throwaway container on the
# same network instead, using an image already proven in this repo
# (microcks-seed uses the same curlimages/curl:8.11.1).
docker run --rm --network gitea-network -v "$(pwd)/governance/gateway/krakend-base.json:/cfg.json:ro" \
  curlimages/curl:8.11.1 -X POST http://krakend-deployer:9000/deploy \
  -H 'Content-Type: application/json' --data-binary @/cfg.json

docker logs krakend --tail 20
curl -sf http://localhost:8090   # still responds after restart
```

Expected: the `POST /deploy` call returns `{"status":"deployed"}`; `krakend`'s logs show it restarted; the final curl still gets a response (container came back up).

- [ ] **Step 7: Tear down**

```bash
docker compose --profile contract --profile gateway down
```

- [ ] **Step 8: Commit**

```bash
git add governance/gateway/deployer/Dockerfile docker-compose.yml
git commit -m "feat: wire krakend + krakend-deployer into docker-compose.yml

New \"gateway\" profile: krakend (KrakenD CE, port 8090) and
krakend-deployer (the sidecar from the previous commit, socket-mounted
like gitea-seed/gitea-runner). Verified manually: both come up, a
POST /deploy round-trip writes config and restarts krakend
successfully."
```

---

### Task 4: Seed the gateway tooling into the governance Gitea repo

**Files:**
- Modify: `scripts/seed-gitea.sh`

**Interfaces:**
- Consumes: Task 1's `governance/gateway/{generate.js,package.json,krakend-base.json}` (NOT `deployer/` — that's platform-side, never cloned by consumer CI).
- Produces: those three files present at `gateway/` inside the pushed `governance-demo/api-governance` Gitea repo.

- [ ] **Step 1: Read the current governance-repo push block**

In `scripts/seed-gitea.sh`, find the section starting `echo "==> push governance repo: lean policy ..."` through the `seed_repo "$GOV_SRC" "$GOV_REPO" ...` call.

- [ ] **Step 2: Extend the `GOV_SRC` staging to include the gateway generator**

Add these lines right after the existing `cp -r /governance/api-guidelines/docs "$GOV_SRC"/` line, before the `seed_repo "$GOV_SRC" "$GOV_REPO" ...` call:

```bash
# Gateway config generator (OpenAPI -> KrakenD), linked the same way as the
# ruleset - the deployer/ subfolder is platform-side (built directly by
# docker-compose) and is intentionally NOT included here.
mkdir -p "$GOV_SRC"/gateway
cp /governance/gateway/generate.js "$GOV_SRC"/gateway/
cp /governance/gateway/package.json "$GOV_SRC"/gateway/
cp /governance/gateway/krakend-base.json "$GOV_SRC"/gateway/
```

- [ ] **Step 3: Manual verification — re-run the seed and check the pushed repo**

No unit-test seam (shell script driving live Gitea state); verify manually, matching this script's existing lack of automated tests.

```bash
docker compose up -d gitea gitea-seed
docker logs gitea-seed --tail 30
```

Expected log line: `==> push governance repo: lean policy -> 'governance-demo/api-governance' main` followed by a successful push, no errors.

```bash
curl -sf -u demo:demo12345 \
  "http://localhost:3000/api/v1/repos/governance-demo/api-governance/contents/gateway" \
  | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); d.forEach(f=>console.log(f.name))"
```

Expected output: three lines — `generate.js`, `krakend-base.json`, `package.json`. No `deployer` entry.

- [ ] **Step 4: Commit**

```bash
git add scripts/seed-gitea.sh
git commit -m "feat: seed the gateway generator into the governance Gitea repo

Extends the existing lean-repo push (ruleset + guidelines) to also
include governance/gateway/{generate.js,package.json,krakend-base.json}
- the same \"linked, not vendored\" pattern, so consumer CI can clone
and run the generator. deployer/ is deliberately excluded - it's
platform infrastructure, not something a consumer repo's CI runs.
Verified manually: re-seeded and confirmed exactly those three files
appear in governance-demo/api-governance's gateway/ directory."
```

---

### Task 5: `gateway-deploy-check` CI gate

**Files:**
- Modify: `example/.gitea/workflows/pr-governance.yml`

**Interfaces:**
- Consumes: Task 1 (generator, via the clone Task 4 makes available), Task 3 (running `krakend`/`krakend-deployer` reachable on `gitea-network`), existing workflow env vars `CONTRACT_FILE`, `MICROCKS_URL`, `MICROCKS_PUBLIC_URL`, `API_TITLE`, `GOVERNANCE_REPO`.
- Produces: a fourth PR check, `gateway-deploy-check`, gated on `contract-test`.

- [ ] **Step 1: Add new env vars**

In the `env:` block at the top of `example/.gitea/workflows/pr-governance.yml`, add after the existing `CONTRACT_FILE: contracts/orders-openapi.yaml` line:

```yaml
  # Server-to-server: job container -> krakend on gitea-network.
  GATEWAY_URL: http://krakend:8090
  # Server-to-server: job container -> krakend-deployer on gitea-network.
  GATEWAY_DEPLOYER_URL: http://krakend-deployer:9000
```

- [ ] **Step 2: Add the `gateway-deploy-check` job**

Append this job at the end of the `jobs:` section, after `contract-test`:

```yaml
  gateway-deploy-check:
    needs: contract-test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout PR branch
        uses: actions/checkout@v4
        with:
          # Same rationale as contract-test: gateway config must come from
          # the PR's contract, not main's.
          ref: ${{ github.event.pull_request.head.sha }}

      - name: Fetch governance gateway tooling (linked, not vendored)
        shell: bash
        run: |
          set -e
          rm -rf .governance-gateway
          git clone --depth 1 "${GOVERNANCE_REPO}" .governance-gateway
          echo "Linked gateway tooling:"; ls .governance-gateway/gateway/generate.js

      - name: Install generator dependencies
        shell: bash
        run: npm install --prefix .governance-gateway/gateway

      - name: Generate krakend.json from the PR contract
        shell: bash
        run: |
          set -e
          node .governance-gateway/gateway/generate.js "${CONTRACT_FILE}" krakend.json
          echo "Generated krakend.json:"; cat krakend.json

      # NOTE for implementer: verify the current KrakenD CE release tag at
      # https://github.com/krakend/krakend-ce/releases before merging this
      # job and adjust KRAKEND_VERSION if a newer stable tag exists.
      - name: Install KrakenD CLI (pinned)
        shell: bash
        env:
          KRAKEND_VERSION: 2.6.2
        run: |
          set -e
          curl -fsSL -o /tmp/krakend.tgz \
            "https://github.com/krakend/krakend-ce/releases/download/v${KRAKEND_VERSION}/krakend_${KRAKEND_VERSION}_linux_amd64.tar.gz"
          tar -xzf /tmp/krakend.tgz -C /tmp
          install -m 0755 /tmp/usr/bin/krakend /usr/local/bin/krakend
          krakend version

      # `krakend check -c <file>` alone is the confirmed base command; if the
      # pinned version's `krakend check --help` offers a stricter lint mode,
      # the implementer should add it here rather than guessing a flag name.
      - name: Validate the generated config (fail on any error)
        shell: bash
        run: krakend check -c krakend.json

      - name: Deploy to the running gateway
        shell: bash
        run: |
          set -e
          curl -sf -X POST "${GATEWAY_DEPLOYER_URL}/deploy" \
            -H 'Content-Type: application/json' \
            --data-binary @krakend.json
          echo "Deployed."

      - name: Wait for KrakenD to be ready
        shell: bash
        run: |
          set -e
          for i in $(seq 1 30); do
            CODE=$(curl -s -o /dev/null -w '%{http_code}' "${GATEWAY_URL}/orders/readiness-probe" || echo "000")
            if [ "$CODE" != "000" ]; then
              echo "KrakenD is up (HTTP $CODE)."
              break
            fi
            if [ "$i" -eq 30 ]; then
              echo "KrakenD did not become ready in time." >&2
              exit 1
            fi
            echo "waiting for KrakenD ($i)..."; sleep 2
          done

      - name: Run contract test through the gateway
        shell: bash
        run: |
          set -e
          # Same contract already imported into Microcks by contract-test -
          # just launch another test run against the gateway's endpoint.
          VERSION=$(grep -E '^[[:space:]]+version:' "${CONTRACT_FILE}" | head -1 \
            | sed -E 's/.*version:[[:space:]]*//' | tr -d '"'"'"' ')
          API_SERVICE="${API_TITLE}:${VERSION}"
          echo "Testing service through gateway: ${API_SERVICE}"
          BODY="{\"serviceId\":\"${API_SERVICE}\",\"testEndpoint\":\"${GATEWAY_URL}\",\"runnerType\":\"OPEN_API_SCHEMA\",\"timeout\":10000}"
          RESP=$(curl -sf -X POST "${MICROCKS_URL}/api/tests" \
            -H 'Content-Type: application/json' -d "${BODY}")
          TID=$(printf '%s' "$RESP" | grep -o '"id":"[a-f0-9]*"' | head -1 | sed 's/.*:"\(.*\)"/\1/')
          if [ -z "$TID" ]; then
            echo "Failed to launch test. Response: $RESP" >&2; exit 1
          fi
          echo "Launched test ${TID}; polling..."

          RESULT=""
          for i in $(seq 1 20); do
            sleep 2
            RESULT=$(curl -sf "${MICROCKS_URL}/api/tests/${TID}")
            printf '%s' "$RESULT" | grep -q '"inProgress":false' && break
            echo "  in progress ($i)..."
          done

          SUCCESS=$(printf '%s' "$RESULT" | grep -o '"success":[a-z]*,"inProgress"' \
            | head -1 | sed 's/"success":\([a-z]*\).*/\1/')
          echo "Test ${TID} success=${SUCCESS}"
          echo "Details: ${MICROCKS_PUBLIC_URL}/#/tests/${TID}"
          if [ "$SUCCESS" != "true" ]; then
            echo "Gateway contract test FAILED:" >&2
            printf '%s\n' "$RESULT" >&2
            exit 1
          fi
          echo "Gateway contract test PASSED."
```

- [ ] **Step 3: Manual verification — full live PR run**

No unit-test seam (this is a CI workflow); verify with a real PR, the same methodology already proven earlier for the other three gates.

```bash
docker compose --profile contract --profile gateway up -d
rm -rf /tmp/gw-e2e && git clone http://demo:demo12345@localhost:3000/governance-demo/devops-api-governance.git /tmp/gw-e2e
cd /tmp/gw-e2e && git switch -c test/gateway-gate main
git commit -q --allow-empty -m "test: trigger gateway-deploy-check"
git push origin test/gateway-gate
```

Then open a PR via the Gitea API (or UI) from `test/gateway-gate` into `main`, poll
`GET /api/v1/repos/governance-demo/devops-api-governance/commits/<sha>/status`
until all four contexts resolve. Expected: `spectral-openapi-check`,
`breaking-changes-check`, `contract-test`, and `gateway-deploy-check` all
`success`. Fetch the `gateway-deploy-check` job's log and confirm the last
line is `Gateway contract test PASSED.`

Clean up: close the PR, delete the branch (`git push origin --delete test/gateway-gate`), remove `/tmp/gw-e2e`.

- [ ] **Step 4: Commit**

```bash
git add example/.gitea/workflows/pr-governance.yml
git commit -m "feat: add gateway-deploy-check as the fourth PR-governance gate

Generates krakend.json from the PR's contract (linked generator), lints
it with krakend check, deploys it via krakend-deployer, waits for
KrakenD to come back up, then re-runs the Microcks test suite already
imported by contract-test - this time against the gateway endpoint
instead of the backend directly, catching gateway-specific
misconfiguration (bad path rewriting, dropped headers) that testing
the backend alone would miss. Verified with a real PR through all four
gates."
```

---

### Task 6: Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/ci-test-path.md`
- Modify: `docs/ci-fixes-scope.md`
- Modify: `tests/pr-governance.feature.md`
- Modify: `CLAUDE.md`

**Interfaces:** none (documentation only; no code consumes these).

- [ ] **Step 1: `README.md` — "The demo loop" gate list**

Find the numbered gate list under `## The demo loop` (the three bullets for
`spectral-openapi-check`, `breaking-changes-check`, `contract-test`). Add a
fourth bullet after `contract-test`'s:

```markdown
  - **Gateway deploy** (`gateway-deploy-check`) — generates a KrakenD gateway
    config from the PR's contract, deploys it to a running KrakenD instance,
    and re-runs the Microcks test suite against the gateway instead of the
    backend directly; **fails on any config-lint error or gateway-level
    contract-test failure**.
```

Also update the sentence "Gitea Actions runs three gates **in order**" to
"**four gates**".

- [ ] **Step 2: `README.md` — endpoints table**

Add a row to the endpoints table near "One command":

```markdown
| KrakenD | http://localhost:8090 | API gateway routing to sample-backend |
```

Update the bring-up command example to mention the new profile:

```markdown
docker compose --profile contract --profile catalog --profile gateway up -d
```

- [ ] **Step 3: `README.md` — repository layout table**

In the "Governance context" table, add a row after the `governance/spectral/` row:

```markdown
| `governance/gateway/` | `generate.js` (OpenAPI→KrakenD generator) + `krakend-base.json` + `deployer/` (sidecar that deploys generated configs to the running KrakenD instance) — the generator is pushed to the `api-governance` Gitea repo and linked by consumer CI; `deployer/` is platform-only, never cloned by consumer CI. |
```

- [ ] **Step 4: `README.md` — roadmap section**

Add a fourth bullet to "Roadmap status":

```markdown
- ✅ **API gateway (KrakenD)** — the PR's contract is deployed to a real
  KrakenD CE gateway and re-tested through it before merge, closing the
  loop from design-time lint through to a running, routable gateway.
```

- [ ] **Step 5: `docs/ci-test-path.md` — add the fourth step**

In "## The path", add a fourth numbered item after `contract-test`'s:

```markdown
4. **`gateway-deploy-check`** — generates a KrakenD config from the PR's
   contract, deploys it to the running gateway, and re-runs the Microcks
   test suite through the gateway instead of the backend.
   - 🔴 **Red**: the generated config fails `krakend check`, or the
     gateway-routed contract test fails (e.g. the gateway drops a header or
     rewrites a path the backend then rejects).
   - 🟢 **Green**: the config validates and the gateway-routed test suite
     passes.
```

- [ ] **Step 6: `docs/ci-fixes-scope.md` — add a section**

Append a new section at the end of the file:

```markdown
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
```

- [ ] **Step 7: `tests/pr-governance.feature.md` — acceptance summary table**

Add a row to the "## Acceptance summary" table:

```markdown
| 11 | Gateway deploy (new Scenario 4) | Spectral/BC/contract-test GREEN, `gateway-deploy-check` deploys config and re-tests through KrakenD | Gitea PR checks + gateway-deploy-check CI log |
```

Add a one-line pointer above the table's closing, noting a full Scenario 4
walkthrough (mirroring Scenarios 1-3's format) is intentionally not written
yet — YAGNI for this iteration, add one if/when the gateway gate needs its
own red-state demo script:

```markdown
> Scenario 4 (gateway deploy) is exercised in Task 5 of
> `docs/superpowers/plans/2026-09-15-krakend-gateway.md`'s manual
> verification step; a full scripted BDD scenario matching Scenarios 1-3's
> format is a reasonable follow-up, not required for this gate to function.
```

- [ ] **Step 8: `CLAUDE.md` — nothing required**

No known-gaps section change needed; this task only exists to confirm that
decision explicitly rather than skip documentation review silently. If
implementation surfaces a real bug (mirroring this session's pattern),
add it to the Known gaps section following the existing format.

- [ ] **Step 9: Commit**

```bash
git add README.md docs/ci-test-path.md docs/ci-fixes-scope.md tests/pr-governance.feature.md
git commit -m "docs: document the gateway-deploy-check gate

Updates the demo-loop gate list, endpoints table, repository layout,
roadmap, ci-test-path walkthrough, ci-fixes-scope rationale, and the
BDD feature file's acceptance summary for the new fourth gate."
```
