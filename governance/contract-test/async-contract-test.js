#!/usr/bin/env node
'use strict';

/**
 * Async contract test: does the running provider publish what the contract
 * says? For every `send` operation in the AsyncAPI contract it asks Microcks
 * (ASYNC_API_SCHEMA runner, through the async minion) to listen on that
 * operation's topic for a while and validate every message that arrives
 * against the operation's payload schema.
 *
 * Topic parameters become MQTT single-level wildcards, so
 * orders/v1/{orderId}/created is tested on orders/v1/+/created and the
 * provider's order ids do not matter.
 *
 * Usage: node async-contract-test.js <contract.yaml>
 * Env:   MICROCKS_URL         Microcks API base (default http://microcks:8080)
 *        MICROCKS_PUBLIC_URL  browser-facing base for report links
 *        BROKER_ENDPOINT      broker as Microcks reaches it (default mqtt://mosquitto:1883)
 *        LISTEN_MS            how long to listen per operation (default 5000)
 * Exit:  0 when every operation passed, 1 otherwise.
 */

const fs = require('fs');
const yaml = require('js-yaml');

const MICROCKS = process.env.MICROCKS_URL || 'http://microcks:8080';
const PUBLIC = process.env.MICROCKS_PUBLIC_URL || 'http://localhost:8180';
const BROKER = process.env.BROKER_ENDPOINT || 'mqtt://mosquitto:1883';
const LISTEN_MS = Number(process.env.LISTEN_MS) || 5000;

const file = process.argv[2];
if (!file) {
  console.error('usage: async-contract-test.js <contract.yaml>');
  process.exit(2);
}

const doc = yaml.load(fs.readFileSync(file, 'utf8'));
const serviceId = `${doc.info.title}:${doc.info.version}`;

// Resolve a local "#/a/b" reference; channels are referenced from operations.
const deref = (node) => {
  if (!node || !node.$ref) return node;
  return node.$ref.replace(/^#\//, '').split('/').reduce((o, k) => o && o[k], doc);
};

const sendOps = Object.entries(doc.operations || {})
  .filter(([, op]) => op.action === 'send')
  .map(([id, op]) => {
    const address = deref(op.channel).address;
    return { id, address, topic: address.replace(/\{[^}]+\}/g, '+') };
  });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function api(path, init) {
  const res = await fetch(`${MICROCKS}${path}`, init);
  if (!res.ok) throw new Error(`${init?.method || 'GET'} ${path}: HTTP ${res.status} ${await res.text()}`);
  return res.json();
}

async function testOperation(op) {
  const operation = `SEND ${op.id}`;
  const started = await api('/api/tests', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      serviceId,
      testEndpoint: `${BROKER}/${op.topic}`,
      runnerType: 'ASYNC_API_SCHEMA',
      timeout: LISTEN_MS,
      filteredOperations: [operation],
    }),
  });

  // Microcks closes a test once messages arrived and were validated. When no
  // message arrives it can stay "in progress", so stop waiting a little
  // after the listening window.
  const deadline = Date.now() + LISTEN_MS + 15000;
  let result = started;
  while (result.inProgress !== false && Date.now() < deadline) {
    await sleep(1000);
    result = await api(`/api/tests/${started.id}`);
  }

  const tc = (result.testCaseResults || []).find((t) => t.operationName === operation) || {};
  const steps = tc.testStepResults || [];
  const failed = steps.filter((s) => !s.success);
  // No message at all is a failure too: the provider is not publishing.
  const ok = result.inProgress === false && result.success === true && steps.length > 0;

  console.log(`${ok ? 'PASS' : 'FAIL'}  ${operation}  on ${op.topic}  ` +
    `(${steps.length} messages, ${failed.length} invalid)`);
  if (!steps.length) console.log('      no message arrived within the listening window');
  const reasons = [...new Set(failed.map((s) => s.message).filter(Boolean))];
  for (const r of reasons.slice(0, 5)) console.log(`      ${r.replace(/\\n|\n/g, '; ').trim()}`);
  console.log(`      report: ${PUBLIC}/#/tests/${started.id}`);
  return ok;
}

(async () => {
  console.log(`Contract test of ${serviceId} against ${BROKER}, listening ${LISTEN_MS} ms per operation`);
  if (!sendOps.length) {
    console.log('No send operations: nothing the provider publishes to test.');
    return;
  }
  // One test per operation, each on its own topic, one after the other: the
  // async minion names its MQTT client after the start time in milliseconds,
  // so two tests started together get the same client id and the broker
  // closes one of the connections.
  const results = [];
  for (const op of sendOps) results.push(await testOperation(op));
  const passed = results.filter(Boolean).length;
  console.log(`${passed}/${results.length} operations passed`);
  process.exit(passed === results.length ? 0 : 1);
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
