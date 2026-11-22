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
 * On Kafka the same checks run with the Kafka client: a consumer may read the
 * contract's topics, is refused a topic outside it, a provider may not join a
 * consumer group, and a wrong password is refused.
 *
 * Usage: node verify-policy.js <contract.yaml> <catalog-info.yaml>
 * Env:   BROKER_URL          MQTT broker (default mqtt://mosquitto:1883)
 *        KAFKA_BROKERS       Kafka bootstrap (default kafka:9092)
 *        BROKER_CREDENTIALS  "user:password,user:password" for the catalog's
 *                            providers and consumers (demo accounts);
 *                            MQTT_CREDENTIALS is read too
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const mqtt = require('mqtt'); // MQTT branch; the Kafka branch loads kafkajs

const [contractFile, catalogFile] = process.argv.slice(2);
const BROKER = process.env.BROKER_URL || 'mqtt://mosquitto:1883';
const creds = Object.fromEntries((process.env.BROKER_CREDENTIALS || process.env.MQTT_CREDENTIALS || '')
  .split(',').filter(Boolean).map((p) => p.split(':')));

const contract = yaml.load(fs.readFileSync(contractFile, 'utf8'));
const isKafka = String(Object.values(contract.servers || {})[0]?.protocol || '').startsWith('kafka');
const entities = yaml.loadAll(fs.readFileSync(catalogFile, 'utf8')).filter(Boolean);
const refName = (r) => String(r).replace(/^[a-z]+:/i, '').replace(/^default\//, '');
// The catalog API entity whose definition is this contract (or the only one),
// as generate-policy.js picks it: a repo can list a REST API next to it.
const apis = entities.filter((e) => e.kind === 'API');
const api = apis.find((e) => {
  const text = e.spec?.definition?.$text;
  return text && path.resolve(path.dirname(catalogFile), text) === path.resolve(contractFile);
}) || (apis.length === 1 ? apis[0] : null);
if (!api) {
  console.error(`No API entity in ${catalogFile} points at ${contractFile}.`);
  process.exit(1);
}
const apiName = api.metadata.name;
const users = (key) => entities
  .filter((e) => e.kind === 'Component' && (e.spec?.[key] || []).map(refName).includes(apiName))
  .map((e) => e.metadata.name);

const deref = (n) => (n && n.$ref ? n.$ref.replace(/^#\//, '').split('/').reduce((o, k) => o && o[k], contract) : n);
const sendTopics = Object.values(contract.operations || {})
  .filter((op) => op.action === 'send')
  .map((op) => deref(op.channel).address.replace(/\{[^}]+\}/g, '+'));
// Same prefix as a real topic, last level not in the contract.
const offContract = isKafka
  ? sendTopics[0].replace(/\.[^.]+\.(v[0-9]+)$/, '.not-in-contract.$1')
  : sendTopics[0].replace(/[^/]+$/, 'not-in-contract');

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

async function verifyKafka() {
  const { Kafka, logLevel } = require('kafkajs');
  const brokers = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
  console.log(`Broker policy check on Kafka ${brokers.join(',')} for ${apiName}`);
  const client = (username, password) => new Kafka({
    clientId: `policy-check-${username}`,
    brokers,
    sasl: { mechanism: 'plain', username, password },
    logLevel: logLevel.NOTHING,
    retry: { retries: 0 },
    connectionTimeout: 5000,
  });
  const describes = async (user, topic) => {
    const admin = client(user, creds[user]).admin();
    try {
      await admin.connect();
      await admin.fetchTopicMetadata({ topics: [topic] });
      return true;
    } catch (err) {
      return false;
    } finally {
      await admin.disconnect().catch(() => {});
    }
  };
  // Joining a consumer group needs READ on the group and on every topic. The
  // check uses its own group (the policy grants groups starting with the
  // component name), so the real consumer's group is left alone. A fresh
  // group per run: a reused one may wait for the previous run's member to
  // time out before the join completes.
  const canConsume = async (user, topics) => {
    const groupId = `${user}-policy-check-${Date.now()}`;
    const consumer = client(user, creds[user]).consumer({ groupId, retry: { retries: 0 } });
    try {
      await consumer.connect();
      await consumer.subscribe({ topics });
      await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('timeout')), 20000);
        consumer.on(consumer.events.GROUP_JOIN, () => { clearTimeout(timer); resolve(); });
        consumer.on(consumer.events.CRASH, ({ payload }) => { clearTimeout(timer); reject(payload.error); });
        consumer.run({ eachMessage: async () => {} }).catch(reject);
      });
      return true;
    } catch (err) {
      if (process.env.DEBUG) console.error(`  ${user} consume: ${err.message}`);
      return false;
    } finally {
      await consumer.disconnect().catch(() => {});
    }
  };

  for (const user of users('consumesApis')) {
    expect(await canConsume(user, sendTopics), `${user} may read ${sendTopics.join(', ')}`);
    expect(!(await describes(user, offContract)), `${user} is denied ${offContract} (not in the contract)`);
  }
  for (const user of users('providesApis')) {
    expect(!(await canConsume(user, [sendTopics[0]])), `${user} is denied reading ${sendTopics[0]} (it only publishes)`);
  }
  const anyone = users('consumesApis')[0] || users('providesApis')[0];
  const admin = client(anyone, 'wrong-password').admin();
  const refused = await admin.connect().then(() => false, () => true);
  await admin.disconnect().catch(() => {});
  expect(refused, 'a client with a wrong password is refused');
}

(async () => {
  if (isKafka) {
    await verifyKafka();
    console.log(failures ? `${failures} check(s) failed` : 'broker policy matches the contract and the catalog');
    process.exit(failures ? 1 : 0);
  }
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
