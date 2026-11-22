'use strict';

/**
 * A consumer of the Order Events Kafka API: reads the contract's topics in
 * the consumer group the broker policy grants it, and logs every event.
 * When the policy does not grant a topic, Kafka refuses it and the log says
 * DENIED; the container restarts and tries again.
 */

const { Kafka, logLevel } = require('kafkajs');

const BROKERS = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
const TOPICS = (process.env.TOPICS || 'orders.order-created.v1,orders.order-paid.v1').split(',');
const USER = process.env.KAFKA_USERNAME || 'orders-kafka-subscriber';

const kafka = new Kafka({
  clientId: USER,
  brokers: BROKERS,
  sasl: { mechanism: 'plain', username: USER, password: process.env.KAFKA_PASSWORD || '' },
  logLevel: logLevel.NOTHING,
});
// The group is named after the component: the policy grants that group.
const consumer = kafka.consumer({ groupId: process.env.GROUP_ID || USER });

async function main() {
  await consumer.connect();
  await consumer.subscribe({ topics: TOPICS, fromBeginning: false });
  console.log(`subscribed to ${TOPICS.join(', ')} as ${USER}`);
  await consumer.run({
    eachMessage: async ({ topic, message }) => console.log(`${topic} key=${message.key} ${message.value}`),
  });
}

const deny = (err) => {
  const denied = /authoriz/i.test(`${err.type || ''} ${err.message}`);
  console.error(`${denied ? 'DENIED' : 'error'} ${TOPICS.join(', ')}: ${err.message}`);
  process.exit(1);
};
consumer.on(consumer.events.CRASH, ({ payload }) => deny(payload.error));
main().catch(deny);

const shutdown = () => consumer.disconnect().finally(() => process.exit(0));
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
