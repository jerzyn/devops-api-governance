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
