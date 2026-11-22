'use strict';

/**
 * A consumer of the Order Events API: subscribes to the topics the contract
 * lists and logs every event. The broker policy grants exactly those topics,
 * so a broader wildcard such as orders/v1/# would be denied. It gives the catalog a "consumes" edge and makes the event flow
 * visible in `docker compose logs -f mqtt-subscriber`.
 */

const mqtt = require('mqtt');

const BROKER_URL = process.env.BROKER_URL || 'mqtt://mosquitto:1883';
const TOPICS = (process.env.TOPICS || 'orders/v1/+/created,orders/v1/+/paid').split(',');

const client = mqtt.connect(BROKER_URL, {
  clientId: process.env.MQTT_CLIENT_ID || 'orders-subscriber',
  username: process.env.MQTT_USERNAME || undefined,
  password: process.env.MQTT_PASSWORD || undefined,
  reconnectPeriod: 2000,
  // Subscribe ourselves on every connect (below), so a subscription the broker
  // policy refuses after a reconnect is logged as DENIED.
  resubscribe: false,
});

client.on('connect', () => {
  client.subscribe(TOPICS, { qos: 1 }, (err, granted) => {
    // mqtt.js reports "every subscription refused" as an error.
    if (err) return console.error(`DENIED ${TOPICS.join(', ')} (${err.message}): not granted by the broker policy`);
    for (const g of granted) {
      // qos 128: the broker policy denied this subscription.
      console.log(`${g.qos === 128 ? 'DENIED' : 'subscribed'} ${g.topic} on ${BROKER_URL}`);
    }
  });
});
client.on('message', (topic, payload) => console.log(`${topic} ${payload.toString()}`));
client.on('error', (err) => console.error(`mqtt error: ${err.message}`));

const shutdown = () => client.end(false, () => process.exit(0));
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
