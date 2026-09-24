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
  name: 'Orders API Gateway (uninitialized)',
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
