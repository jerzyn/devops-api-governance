'use strict';

/**
 * Provider under test for the Order Events Kafka API
 * (contracts/order-events-kafka-asyncapi.yaml).
 *
 * Every PUBLISH_INTERVAL_MS it simulates one order: OrderCreated on
 * orders.order-created.v1, then OrderPaid on orders.order-paid.v1, keyed by
 * the order id so both land on the same partition, in order.
 *
 * Before sending, it validates each event against the schema registered for
 * its topic in Apicurio Registry (the "serializer" check): an event that does
 * not match is not sent, and the log says why.
 *
 *   DRIFT unset / "false" -> conformant events
 *   DRIFT = "true"        -> drifted events, rejected before they reach Kafka
 *   REGISTRY_VALIDATION = "false" -> send without the registry check, so the
 *                            contract test sees the drift instead
 */

const { Kafka, logLevel } = require('kafkajs');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const BROKERS = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
const INTERVAL = Number(process.env.PUBLISH_INTERVAL_MS) || 1000;
const DRIFT = String(process.env.DRIFT).toLowerCase() === 'true';
const VALIDATE = String(process.env.REGISTRY_VALIDATION).toLowerCase() !== 'false';
const REGISTRY = (process.env.REGISTRY_URL || 'http://apicurio:8080/apis/registry/v3').replace(/\/$/, '');
const GROUP = process.env.REGISTRY_GROUP || 'order-events-kafka-api';
const FIXED_ORDER_ID = process.env.FIXED_ORDER_ID ?? '123';

const TOPICS = { created: 'orders.order-created.v1', paid: 'orders.order-paid.v1' };

let counter = 0;
const nextOrderId = () => FIXED_ORDER_ID || String(1000 + (++counter));

const orderCreated = (orderId) => (DRIFT
  ? { orderId: Number(orderId), created: new Date().toISOString() }
  : { orderId, createdAt: new Date().toISOString() });
const orderPaid = (orderId) => (DRIFT
  ? { orderId: Number(orderId), paid: 'yes' }
  : { orderId, isPaid: true });

// Registry check: the latest schema of each topic, compiled once and
// refreshed every minute so a newly registered version takes effect.
const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);
const validators = {};
async function refreshSchemas() {
  for (const topic of Object.values(TOPICS)) {
    try {
      const res = await fetch(`${REGISTRY}/groups/${GROUP}/artifacts/${topic}/versions/branch=latest/content`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const schema = await res.json();
      delete schema.$schema;
      validators[topic] = ajv.compile(schema);
    } catch (err) {
      if (!validators[topic]) console.error(`registry: no schema for ${topic} yet (${err.message})`);
    }
  }
}

const kafka = new Kafka({
  clientId: 'orders-kafka-backend',
  brokers: BROKERS,
  sasl: {
    mechanism: 'plain',
    username: process.env.KAFKA_USERNAME || 'orders-kafka-backend',
    password: process.env.KAFKA_PASSWORD || '',
  },
  logLevel: logLevel.WARN,
  retry: { retries: 10 },
});
const producer = kafka.producer({ allowAutoTopicCreation: false });

async function send(topic, key, event) {
  if (VALIDATE) {
    const validate = validators[topic];
    if (!validate) return console.error(`not sent to ${topic}: no registry schema to check against`);
    if (!validate(event)) {
      const why = validate.errors.map((e) => `${e.instancePath || '/'} ${e.message}`).join('; ');
      return console.error(`REJECTED by the registry schema of ${topic}: ${why}`);
    }
  }
  await producer.send({ topic, messages: [{ key, value: JSON.stringify(event) }] });
}

async function main() {
  console.log(`brokers ${BROKERS.join(',')}; drift=${DRIFT}; registry check=${VALIDATE}; every ${INTERVAL} ms`);
  if (VALIDATE) {
    await refreshSchemas();
    setInterval(refreshSchemas, 60000);
  }
  await producer.connect();
  setInterval(async () => {
    const orderId = nextOrderId();
    try {
      await send(TOPICS.created, orderId, orderCreated(orderId));
      await send(TOPICS.paid, orderId, orderPaid(orderId));
    } catch (err) {
      // e.g. TOPIC_AUTHORIZATION_FAILED when the broker policy does not grant it
      console.error(`send failed: ${err.message}`);
    }
  }, INTERVAL);
}

main().catch((err) => { console.error(err.message); process.exit(1); });

const shutdown = () => producer.disconnect().finally(() => process.exit(0));
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
