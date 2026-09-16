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
    output_encoding: 'no-op',
    backend: [
      {
        url_pattern: '/orders/{orderId}',
        method: 'GET',
        host: ['http://sample-backend:8081'],
        encoding: 'no-op',
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

test('generate throws for a contract with no operations, rather than writing an empty config', () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'krakend-gen-'));
  const contractPath = path.join(tmpDir, 'contract.yaml');
  const basePath = path.join(tmpDir, 'base.json');
  fs.writeFileSync(contractPath, ['paths:', '  /health:', '    summary: no methods here'].join('\n'));
  fs.writeFileSync(basePath, JSON.stringify({ version: 3, name: 'Test Gateway', port: 8090 }));

  assert.throws(
    () => generate(contractPath, basePath, 'http://sample-backend:8081'),
    /No operations found in contract/
  );
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
