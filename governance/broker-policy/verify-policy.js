#!/usr/bin/env node
'use strict';

/**
 * Checks the broker policy that is live on the broker, from the outside, the
 * way clients see it. For the API in the contract and the catalog:
 *
 *   - every consumer may subscribe to every topic it reads;
 *   - a consumer may NOT subscribe to a topic that is not in the contract;
 *   - a provider may NOT subscribe to the topics it only writes;
 *   - a client without credentials cannot connect.
 *
 * Usage: node verify-policy.js <contract.yaml> <catalog-info.yaml>
 * Env:   BROKER_URL         (default mqtt://mosquitto:1883)
 *        MQTT_CREDENTIALS   "user:password,user:password" for the catalog's
 *                           providers and consumers (demo accounts)
 */

const fs = require('fs');
const yaml = require('js-yaml');
const mqtt = require('mqtt');

const [contractFile, catalogFile] = process.argv.slice(2);
const BROKER = process.env.BROKER_URL || 'mqtt://mosquitto:1883';
const creds = Object.fromEntries((process.env.MQTT_CREDENTIALS || '')
  .split(',').filter(Boolean).map((p) => p.split(':')));

const contract = yaml.load(fs.readFileSync(contractFile, 'utf8'));
const entities = yaml.loadAll(fs.readFileSync(catalogFile, 'utf8')).filter(Boolean);
const refName = (r) => String(r).replace(/^[a-z]+:/i, '').replace(/^default\//, '');
const apiName = entities.find((e) => e.kind === 'API').metadata.name;
const users = (key) => entities
  .filter((e) => e.kind === 'Component' && (e.spec?.[key] || []).map(refName).includes(apiName))
  .map((e) => e.metadata.name);

const deref = (n) => (n && n.$ref ? n.$ref.replace(/^#\//, '').split('/').reduce((o, k) => o && o[k], contract) : n);
const sendTopics = Object.values(contract.operations || {})
  .filter((op) => op.action === 'send')
  .map((op) => deref(op.channel).address.replace(/\{[^}]+\}/g, '+'));
// Same prefix as a real topic, last level not in the contract.
const offContract = sendTopics[0].replace(/[^/]+$/, 'not-in-contract');

const connect = (username) => new Promise((resolve) => {
  const client = mqtt.connect(BROKER, {
    clientId: `policy-check-${username || 'anonymous'}-${process.pid}`,
    username,
    password: username ? creds[username] : undefined,
    reconnectPeriod: 0,
    connectTimeout: 5000,
  });
  client.once('connect', () => resolve({ client }));
  client.once('error', (err) => { client.end(true); resolve({ error: err.message }); });
});

const canSubscribe = (client, topic) => new Promise((resolve) => {
  client.subscribe(topic, { qos: 1 }, (err, granted) => {
    if (err) return resolve(false);
    resolve(granted[0].qos !== 128);
  });
});

let failures = 0;
const expect = (ok, text) => {
  console.log(`${ok ? 'ok  ' : 'FAIL'}  ${text}`);
  if (!ok) failures++;
};

(async () => {
  console.log(`Broker policy check on ${BROKER} for ${apiName}`);

  for (const user of users('consumesApis')) {
    const { client, error } = await connect(user);
    if (!client) { expect(false, `${user} connects (${error})`); continue; }
    for (const t of sendTopics) expect(await canSubscribe(client, t), `${user} may subscribe to ${t}`);
    expect(!(await canSubscribe(client, offContract)), `${user} is denied ${offContract} (not in the contract)`);
    client.end(true);
  }

  for (const user of users('providesApis')) {
    const { client, error } = await connect(user);
    if (!client) { expect(false, `${user} connects (${error})`); continue; }
    expect(!(await canSubscribe(client, sendTopics[0])), `${user} is denied reading ${sendTopics[0]} (it only publishes)`);
    client.end(true);
  }

  const anon = await connect(undefined);
  expect(!anon.client, 'a client without credentials is refused');
  if (anon.client) anon.client.end(true);

  console.log(failures ? `${failures} check(s) failed` : 'broker policy matches the contract and the catalog');
  process.exit(failures ? 1 : 0);
})();
