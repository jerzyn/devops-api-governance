#!/usr/bin/env node
'use strict';

/**
 * Generates the broker policy for one async API from two sources the team
 * already maintains:
 *
 *   - the AsyncAPI contract: which topics exist and who sends on them
 *     (operation action send/receive, channel address);
 *   - the catalog (catalog-info.yaml): which components provide the API and
 *     which consume it (providesApis / consumesApis).
 *
 * A send operation lets providers publish and consumers subscribe to its
 * topic; a receive operation the other way round. Topic parameters become +
 * wildcards. Microcks may subscribe to every topic (contract tests) and
 * publish its mock topics. Anything not listed is denied by the broker: a
 * topic that is not in the contract, or a client that is not in the catalog.
 *
 * Output (JSON, applied by broker-policy-deployer):
 *   { "protocol", "api", "version",
 *     "topics":  [ { "name", "partitions", "replicas", "config" } ]   (Kafka only,
 *                from the channel bindings),
 *     "clients": { "<account>": { "publish": [], "subscribe": [],
 *                                 "groups": [], "groupPrefix": [],
 *                                 "publishPrefix": [] } } }
 *
 * MQTT topics turn parameters into + wildcards; Kafka topics are literal.
 *
 * Usage: node generate-policy.js <contract.yaml> <catalog-info.yaml> [out.json]
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const [contractFile, catalogFile, outFile] = process.argv.slice(2);
if (!contractFile || !catalogFile) {
  console.error('usage: generate-policy.js <contract.yaml> <catalog-info.yaml> [out.json]');
  process.exit(2);
}

const contract = yaml.load(fs.readFileSync(contractFile, 'utf8'));
const entities = yaml.loadAll(fs.readFileSync(catalogFile, 'utf8')).filter(Boolean);

// Strip "api:" kind and "default/" namespace from an entity reference.
const refName = (ref) => String(ref).replace(/^[a-z]+:/i, '').replace(/^default\//, '');

// The catalog API entity whose definition is this contract (or the only one).
const apis = entities.filter((e) => e.kind === 'API');
const contractPath = path.resolve(contractFile);
const api = apis.find((e) => {
  const text = e.spec?.definition?.$text;
  return text && path.resolve(path.dirname(catalogFile), text) === contractPath;
}) || (apis.length === 1 ? apis[0] : null);
if (!api) {
  console.error(`No API entity in ${catalogFile} points at ${contractFile}.`);
  process.exit(1);
}
const apiName = api.metadata.name;

const components = entities.filter((e) => e.kind === 'Component');
const providers = components
  .filter((c) => (c.spec?.providesApis || []).map(refName).includes(apiName))
  .map((c) => c.metadata.name);
const consumers = components
  .filter((c) => (c.spec?.consumesApis || []).map(refName).includes(apiName))
  .map((c) => c.metadata.name);

const deref = (node) => (node && node.$ref
  ? node.$ref.replace(/^#\//, '').split('/').reduce((o, k) => o && o[k], contract)
  : node);

// The broker the contract's servers name: mqtt / secure-mqtt or kafka / kafka-secure.
const protocol = Object.values(contract.servers || {})[0]?.protocol || 'mqtt';
const isKafka = protocol.startsWith('kafka');

const clients = {};
const grant = (user, access, topic) => {
  clients[user] = clients[user] || { publish: [], subscribe: [] };
  if (!clients[user][access].includes(topic)) clients[user][access].push(topic);
};

// Mock topics. MQTT: "<Title without spaces>-<version>-<address>".
// Kafka: "<Title without spaces>-<version>-<operation id>", all under one prefix.
const mockPrefix = `${contract.info.title.replace(/\s+/g, '')}-${contract.info.version}-`;
const topics = [];

for (const op of Object.values(contract.operations || {})) {
  const channel = deref(op.channel);
  const address = channel?.address;
  if (!address) continue;
  const topic = isKafka ? address : address.replace(/\{[^}]+\}/g, '+');
  const [publishers, subscribers] = op.action === 'send' ? [providers, consumers] : [consumers, providers];
  publishers.forEach((u) => grant(u, 'publish', topic));
  subscribers.forEach((u) => grant(u, 'subscribe', topic));
  // Contract tests listen on the real topic; mocks go to their own topic.
  // On Kafka, Microcks connects through the platform listener as ANONYMOUS.
  const platform = isKafka ? 'ANONYMOUS' : 'microcks';
  grant(platform, 'subscribe', topic);
  if (!isKafka) grant(platform, 'publish', `${mockPrefix}${address}`);
  else if (!topics.some((t) => t.name === topic)) {
    const b = channel.bindings?.kafka || {};
    topics.push({
      name: topic,
      partitions: b.partitions || 1,
      replicas: b.replicas || 1,
      config: Object.fromEntries(Object.entries(b.topicConfiguration || {})
        .map(([k, v]) => [k, Array.isArray(v) ? v.join(',') : String(v)])),
    });
  }
}

if (isKafka) {
  // Kafka consumers read in consumer groups whose names start with the
  // component name; Microcks' test consumers use generated group ids.
  for (const u of subscribersOf()) clients[u].groupPrefix = [u];
  clients.ANONYMOUS = clients.ANONYMOUS || { publish: [], subscribe: [] };
  clients.ANONYMOUS.groups = ['*'];
  clients.ANONYMOUS.publishPrefix = [mockPrefix];
}

// Platform: the observer account reads everything, for demos and debugging.
grant('observer', 'subscribe', isKafka ? '*' : '#');
if (isKafka) clients.observer.groups = ['observer'];

function subscribersOf() {
  return Object.entries(clients)
    .filter(([u, c]) => c.subscribe.length && u !== 'ANONYMOUS')
    .map(([u]) => u);
}

const policy = {
  protocol: isKafka ? 'kafka' : 'mqtt',
  api: apiName,
  title: contract.info.title,
  version: contract.info.version,
  providers,
  consumers,
  ...(isKafka ? { topics } : {}),
  clients,
};

const json = `${JSON.stringify(policy, null, 2)}\n`;
if (outFile) fs.writeFileSync(outFile, json);
else process.stdout.write(json);
