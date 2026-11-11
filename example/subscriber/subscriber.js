'use strict';

/**
 * A consumer of the Order Events API: subscribes to every order's events and
 * logs them. It gives the catalog a "consumes" edge and makes the event flow
 * visible in `docker compose logs -f subscriber`.
 */

const mqtt = require('mqtt');

const BROKER_URL = process.env.BROKER_URL || 'mqtt://mosquitto:1883';
const TOPIC = process.env.TOPIC || 'orders/v1/+/+';

const client = mqtt.connect(BROKER_URL, {
  clientId: process.env.MQTT_CLIENT_ID || 'orders-subscriber',
  username: process.env.MQTT_USERNAME || undefined,
  password: process.env.MQTT_PASSWORD || undefined,
  reconnectPeriod: 2000,
});

client.on('connect', () => {
  client.subscribe(TOPIC, { qos: 1 }, (err) => {
    if (err) console.error(`subscribe to ${TOPIC} failed: ${err.message}`);
    else console.log(`subscribed to ${TOPIC} on ${BROKER_URL}`);
  });
});
client.on('message', (topic, payload) => console.log(`${topic} ${payload.toString()}`));
client.on('error', (err) => console.error(`mqtt error: ${err.message}`));

const shutdown = () => client.end(false, () => process.exit(0));
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
