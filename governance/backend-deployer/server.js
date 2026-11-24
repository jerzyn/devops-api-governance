'use strict';

/**
 * Deploys a backend's source code into its running container, so the
 * contract test checks the code of the PR rather than whatever runs.
 *
 *   POST /deploy/<container>   body: gzipped tar of the backend folder
 *     -> unpacks it and copies it over /app in the container; the backend
 *        runs under `node --watch` and reloads itself
 *   GET  /health
 *
 * No restart: on Podman, restarting a container whose dependencies (the
 * one-shot seeds) have exited fails with "container state improper".
 *
 * Only the containers in TARGETS can be deployed. The image stays as built
 * (node_modules included), only the sources change: a PR that changes
 * dependencies needs a rebuild instead. Files a PR deletes stay in the
 * container until it is recreated. The code lives in the container's own
 * layer: a compose `up` that recreates the container brings back the image's
 * code (`demo goto` deploys the step's backends again).
 *
 * Like krakend-deployer, this needs the container engine socket, so the CI
 * job containers don't.
 */

const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFile } = require('child_process');

const PORT = Number(process.env.PORT) || 9200;
const CONTAINER_ENGINE = process.env.CONTAINER_ENGINE || 'docker';
const TARGETS = (process.env.TARGETS || 'backend,mqtt-backend').split(',').map((t) => t.trim());
const APP_DIR = process.env.APP_DIR || '/app';
const MAX_BODY = 5 * 1024 * 1024;
// How long the backend gets to reload after the copy before we answer.
const SETTLE_MS = Number(process.env.SETTLE_MS ?? 3000);

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, (error, stdout, stderr) => {
      if (error) reject(new Error((stderr || error.message).trim()));
      else resolve(stdout);
    });
  });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY) reject(new Error('body too large'));
      else chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function sendJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

async function deploy(target, body) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `deploy-${target}-`));
  try {
    const archive = path.join(dir, 'src.tar.gz');
    const src = path.join(dir, 'src');
    fs.writeFileSync(archive, body);
    fs.mkdirSync(src);
    try {
      await run('tar', ['-xzf', archive, '-C', src]);
    } catch (e) {
      return { status: 400, body: { error: `body is not a gzipped tar: ${e.message}` } };
    }
    try {
      await run(CONTAINER_ENGINE, ['cp', `${src}/.`, `${target}:${APP_DIR}`]);
    } catch (e) {
      return { status: 502, body: { error: `failed to deploy ${target}: ${e.message}` } };
    }
    await new Promise((resolve) => setTimeout(resolve, SETTLE_MS));
    return { status: 200, body: { status: 'deployed', target } };
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const server = http.createServer(async (req, res) => {
  const match = req.url.match(/^\/deploy\/([a-z0-9-]+)$/);
  if (req.method === 'POST' && match) {
    const target = match[1];
    if (!TARGETS.includes(target)) {
      return sendJson(res, 404, { error: `unknown target ${target}; known: ${TARGETS.join(', ')}` });
    }
    let body;
    try {
      body = await readBody(req);
    } catch (e) {
      return sendJson(res, 400, { error: e.message });
    }
    const result = await deploy(target, body);
    console.log(`deploy ${target}: ${result.status}`);
    return sendJson(res, result.status, result.body);
  }

  if (req.method === 'GET' && req.url === '/health') {
    return sendJson(res, 200, { status: 'ok' });
  }

  return sendJson(res, 404, { error: 'not found' });
});

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`backend-deployer listening on :${PORT}, targets: ${TARGETS.join(', ')}`);
  });
}

module.exports = { server };
