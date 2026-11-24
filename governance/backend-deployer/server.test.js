'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

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

// A fake engine that logs its arguments and, for `cp SRC/. CONTAINER:/app`,
// copies SRC into $FAKE_APP so the test can see what would land in the
// container.
function fakeEngine(dir, exitCode = 0) {
  const log = path.join(dir, 'engine.log');
  const app = path.join(dir, 'app');
  const bin = path.join(dir, 'engine.sh');
  fs.writeFileSync(
    bin,
    `#!/bin/sh
echo "$@" >> "${log}"
if [ "$1" = cp ]; then mkdir -p "${app}"; cp -R "$2" "${app}/"; fi
exit ${exitCode}
`
  );
  fs.chmodSync(bin, 0o755);
  return { bin, log, app };
}

// A gzipped tar of a backend folder, as the CI job sends it.
function tarball(dir) {
  const src = path.join(dir, 'src');
  fs.mkdirSync(src);
  fs.writeFileSync(path.join(src, 'server.js'), 'console.log("v2");\n');
  return execFileSync('tar', ['-czf', '-', '-C', src, '.']);
}

test('POST /deploy/backend copies the sources into the container, without restarting it', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'backend-deployer-'));
  const engine = fakeEngine(dir);
  const server = freshServer({ CONTAINER_ENGINE: engine.bin, TARGETS: 'backend,mqtt-backend', SETTLE_MS: '0' });
  const port = await listen(server);

  const result = await request(
    port,
    { method: 'POST', path: '/deploy/backend', headers: { 'Content-Type': 'application/gzip' } },
    tarball(dir)
  );
  server.close();

  assert.equal(result.status, 200);
  assert.deepEqual(JSON.parse(result.body), { status: 'deployed', target: 'backend' });
  const calls = fs.readFileSync(engine.log, 'utf8').trim().split('\n');
  // No restart: on Podman a restart refuses a container whose dependencies
  // (the one-shot seeds) have exited. The backend reloads itself (node --watch).
  assert.equal(calls.length, 1);
  assert.match(calls[0], /^cp \S+\/\. backend:\/app$/);
  assert.equal(fs.readFileSync(path.join(engine.app, 'server.js'), 'utf8'), 'console.log("v2");\n');
});

test('POST /deploy/<unknown> returns 404 and runs no engine command', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'backend-deployer-'));
  const engine = fakeEngine(dir);
  const server = freshServer({ CONTAINER_ENGINE: engine.bin, TARGETS: 'backend', SETTLE_MS: '0' });
  const port = await listen(server);

  const result = await request(port, { method: 'POST', path: '/deploy/gitea' }, tarball(dir));
  server.close();

  assert.equal(result.status, 404);
  assert.equal(fs.existsSync(engine.log), false);
});

test('POST /deploy/backend with a body that is not a tarball returns 400', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'backend-deployer-'));
  const engine = fakeEngine(dir);
  const server = freshServer({ CONTAINER_ENGINE: engine.bin, TARGETS: 'backend', SETTLE_MS: '0' });
  const port = await listen(server);

  const result = await request(port, { method: 'POST', path: '/deploy/backend' }, 'not a tarball');
  server.close();

  assert.equal(result.status, 400);
  assert.equal(fs.existsSync(engine.log), false);
});

test('POST /deploy/backend returns 502 when the engine fails', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'backend-deployer-'));
  const engine = fakeEngine(dir, 1);
  const server = freshServer({ CONTAINER_ENGINE: engine.bin, TARGETS: 'backend', SETTLE_MS: '0' });
  const port = await listen(server);

  const result = await request(port, { method: 'POST', path: '/deploy/backend' }, tarball(dir));
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
