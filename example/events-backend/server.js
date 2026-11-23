'use strict';

/**
 * Provider under test for the Order Events API
 * (contracts/order-events-asyncapi.yaml).
 *
 * Every PUBLISH_INTERVAL_MS it simulates one order: it publishes OrderCreated,
 * then OrderPaid, on orders/v1/{orderId}/created and orders/v1/{orderId}/paid. The contract test listens on
 * the broker and validates what arrives, so the backend must keep publishing.
 *
 * Two modes, selected by the DRIFT environment variable:
 *   DRIFT unset / "false" -> conformant events   (contract test PASS)
 *   DRIFT = "true"        -> drifted events      (contract test FAIL)
 */

const mqtt = require('mqtt');

const BROKER_URL = process.env.BROKER_URL || 'mqtt://mosquitto:1883';
const INTERVAL = Number(process.env.PUBLISH_INTERVAL_MS) || 1000;
const DRIFT = String(process.env.DRIFT).toLowerCase() === 'true';
// A fixed order id makes the topic predictable for demos and contract tests;
// set FIXED_ORDER_ID= (empty) to get a new id for every simulated order.
const FIXED_ORDER_ID = process.env.FIXED_ORDER_ID ?? '123';

let counter = 0;
const nextOrderId = () => FIXED_ORDER_ID || String(1000 + (++counter));

function orderCreated(orderId) {
  if (DRIFT) {
    // Wrong type for orderId, createdAt renamed: both break the contract.
    return { orderId: Number(orderId), created: new Date().toISOString() };
  }
  return { orderId, createdAt: new Date().toISOString() };
}

function orderPaid(orderId) {
  if (DRIFT) {
    return { orderId: Number(orderId), paid: 'yes' };
  }
  return { orderId, isPaid: true };
}

const client = mqtt.connect(BROKER_URL, {
  clientId: process.env.MQTT_CLIENT_ID || 'orders-backend',
  username: process.env.MQTT_USERNAME || undefined,
  password: process.env.MQTT_PASSWORD || undefined,
  reconnectPeriod: 2000,
});

function publish(topic, payload) {
  client.publish(topic, JSON.stringify(payload), { qos: 1, retain: false }, (err) => {
    if (err) console.error(`publish to ${topic} failed: ${err.message}`);
  });
}

client.on('connect', () => {
  console.log(`connected to ${BROKER_URL}; drift=${DRIFT}; every ${INTERVAL} ms`);
});
client.on('error', (err) => console.error(`mqtt error: ${err.message}`));

setInterval(() => {
  if (!client.connected) return;
  const orderId = nextOrderId();
  publish(`orders/v1/${orderId}/created`, orderCreated(orderId));
  publish(`orders/v1/${orderId}/paid`, orderPaid(orderId));
}, INTERVAL);

const shutdown = () => client.end(false, () => process.exit(0));
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
