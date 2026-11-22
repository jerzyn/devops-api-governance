#!/usr/bin/env node
'use strict';

/**
 * Payload compatibility through Apicurio Registry.
 *
 * Every topic in the contract carries one message type (guideline mqtt6), so
 * each topic's payload schema is one JSON Schema artifact in the registry:
 *   group     the API (catalog name, from the contract title)
 *   artifact  the topic address, e.g. orders.v1.orderId.paid
 *
 * The COMPATIBILITY rule follows who reads the payload:
 *   send    (the API publishes, consumers read)   FORWARD:  consumers built
 *           on the previous schema must read what the new producer sends
 *   receive (the API reads, clients publish)       BACKWARD: the new reader
 *           must read what existing publishers send
 *   both                                          FULL
 *
 *   check <contract>     dry run: would each payload be accepted as the next
 *                        version? Exit 1 on any incompatible payload.
 *   register <contract>  store each payload as the next version (and set the
 *                        rule). Used for main: at startup and after a merge.
 *
 * Env: REGISTRY_URL (default http://apicurio:8080/apis/registry/v3)
 */

const { Parser, fromFile } = require('@asyncapi/parser');

const REGISTRY = (process.env.REGISTRY_URL || 'http://apicurio:8080/apis/registry/v3').replace(/\/$/, '');
const [mode, file] = process.argv.slice(2);
if (!['check', 'register'].includes(mode) || !file) {
  console.error('usage: schema-registry.js check|register <contract.yaml>');
  process.exit(2);
}

const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const artifactIdFor = (address) => address.replace(/[{}]/g, '').split('/').join('.');

// The parser adds x-parser-* bookkeeping keys; the registry should not see them.
const clean = (node) => {
  if (Array.isArray(node)) return node.map(clean);
  if (!node || typeof node !== 'object') return node;
  return Object.fromEntries(Object.entries(node)
    .filter(([k]) => !k.startsWith('x-parser-'))
    .map(([k, v]) => [k, clean(v)]));
};

async function payloads() {
  const { document, diagnostics } = await fromFile(new Parser(), file).parse();
  if (!document) {
    throw new Error(`cannot parse ${file}: ${diagnostics.filter((d) => d.severity === 0).map((d) => d.message).join('; ')}`);
  }
  const doc = document.json();
  const byTopic = new Map();
  for (const op of Object.values(doc.operations || {})) {
    const address = op.channel?.address;
    if (!address) continue;
    for (const msg of op.messages || []) {
      const entry = byTopic.get(address) || { address, message: msg.name, actions: new Set(), payload: msg.payload };
      entry.actions.add(op.action);
      byTopic.set(address, entry);
    }
  }
  const group = slug(doc.info.title);
  return [...byTopic.values()].map((e) => ({
    group,
    artifactId: artifactIdFor(e.address),
    address: e.address,
    message: e.message,
    rule: e.actions.size === 2 ? 'FULL' : e.actions.has('send') ? 'FORWARD' : 'BACKWARD',
    schema: JSON.stringify({ $schema: 'http://json-schema.org/draft-07/schema#', ...clean(e.payload) }, null, 2),
  }));
}

async function call(method, path, body) {
  const res = await fetch(`${REGISTRY}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
  return { status: res.status, json };
}

const WHO = {
  FORWARD: 'consumers built on the registered schema could not read what the API would now send',
  BACKWARD: 'the API could not read what existing publishers send',
  FULL: 'old and new payloads cannot be read both ways',
};

const version = (schema) => ({ content: { content: schema, contentType: 'application/json' } });
const causes = (json) => (json.causes || []).map((c) => `${c.description}${c.context ? ` at ${c.context}` : ''}`);

async function check(p) {
  const art = `/groups/${p.group}/artifacts/${encodeURIComponent(p.artifactId)}`;
  const existing = await call('GET', art);
  if (existing.status === 404) {
    console.log(`new   ${p.address} (${p.message}): not in the registry yet, nothing to break`);
    return true;
  }
  const res = await call('POST', `${art}/versions?dryRun=true`, version(p.schema));
  if (res.status === 200) {
    console.log(`ok    ${p.address} (${p.message}): ${p.rule}-compatible with the registered schema`);
    return true;
  }
  console.log(`FAIL  ${p.address} (${p.message}): not ${p.rule}-compatible with the registered schema`);
  console.log(`      ${WHO[p.rule]}`);
  for (const c of causes(res.json)) console.log(`      ${c}`);
  if (!causes(res.json).length) console.log(`      HTTP ${res.status}: ${res.json.detail || res.json.message || JSON.stringify(res.json)}`);
  return false;
}

async function register(p) {
  const res = await call('POST', `/groups/${p.group}/artifacts?ifExists=FIND_OR_CREATE_VERSION`, {
    artifactId: p.artifactId,
    artifactType: 'JSON',
    name: `${p.message} on ${p.address}`,
    firstVersion: version(p.schema),
  });
  if (res.status >= 300) {
    console.log(`FAIL  ${p.address}: HTTP ${res.status} ${causes(res.json).join('; ') || res.json.detail || ''}`);
    return false;
  }
  const art = `/groups/${p.group}/artifacts/${encodeURIComponent(p.artifactId)}`;
  const rule = await call('GET', `${art}/rules/COMPATIBILITY`);
  if (rule.status === 404) await call('POST', `${art}/rules`, { ruleType: 'COMPATIBILITY', config: p.rule });
  else if (rule.json.config !== p.rule) await call('PUT', `${art}/rules/COMPATIBILITY`, { ruleType: 'COMPATIBILITY', config: p.rule });
  const v = res.json.version?.version ?? res.json.version;
  console.log(`ok    ${p.address} (${p.message}): ${p.group}/${p.artifactId} version ${v}, rule ${p.rule}`);
  return true;
}

(async () => {
  const list = await payloads();
  console.log(`${mode === 'check' ? 'Checking' : 'Registering'} ${list.length} payload schema(s) of ${file} in ${REGISTRY}`);
  const results = [];
  for (const p of list) results.push(await (mode === 'check' ? check(p) : register(p)));
  process.exit(results.every(Boolean) ? 0 : 1);
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
