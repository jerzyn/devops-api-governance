#!/usr/bin/env node
'use strict';

/**
 * Structural breaking changes between two versions of an AsyncAPI contract,
 * with @asyncapi/diff. What it catches: a topic (channel address) changed, an
 * operation or channel removed, an operation's action flipped, MQTT qos or
 * retain changed.
 *
 * Payload schemas are not judged here: @asyncapi/diff leaves them
 * unclassified, and the registry checks them with real compatibility rules
 * (schema-registry.js). Overrides follow the diff library's rule that every
 * parent pointer of an overridden path is listed too.
 *
 * Usage: node asyncapi-diff.js <base.yaml> <head.yaml>   exit 1 on breaking
 */

const { Parser, fromFile } = require('@asyncapi/parser');
const { diff } = require('@asyncapi/diff');

const [baseFile, headFile] = process.argv.slice(2);
if (!baseFile || !headFile) {
  console.error('usage: asyncapi-diff.js <base.yaml> <head.yaml>');
  process.exit(2);
}

const OVERRIDES = {
  '/operations/*/bindings': { add: 'non-breaking', remove: 'breaking', edit: 'unclassified' },
  '/operations/*/bindings/mqtt': { add: 'non-breaking', remove: 'breaking', edit: 'unclassified' },
  // Consumers size retries and deduplication by these: any change breaks them.
  '/operations/*/bindings/mqtt/qos': { add: 'breaking', remove: 'breaking', edit: 'breaking' },
  '/operations/*/bindings/mqtt/retain': { add: 'breaking', remove: 'breaking', edit: 'breaking' },
  // Kafka. The key picks the partition: a new partition count or a changed
  // key reshuffles which partition an entity's events land on, so consumers
  // lose their per-entity order. Compaction changes what a replay returns.
  '/channels/*/bindings': { add: 'non-breaking', remove: 'breaking', edit: 'unclassified' },
  '/channels/*/bindings/kafka': { add: 'non-breaking', remove: 'breaking', edit: 'unclassified' },
  '/channels/*/bindings/kafka/partitions': { add: 'non-breaking', remove: 'breaking', edit: 'breaking' },
  '/channels/*/bindings/kafka/topicConfiguration': { add: 'non-breaking', remove: 'unclassified', edit: 'unclassified' },
  '/channels/*/bindings/kafka/topicConfiguration/cleanup.policy': { add: 'breaking', remove: 'breaking', edit: 'breaking' },
  '/channels/*/bindings/kafka/topicConfiguration/cleanup.policy/*': { add: 'breaking', remove: 'breaking', edit: 'breaking' },
  '/channels/*/messages/*/bindings': { add: 'non-breaking', remove: 'breaking', edit: 'unclassified' },
  '/channels/*/messages/*/bindings/kafka': { add: 'non-breaking', remove: 'breaking', edit: 'unclassified' },
  '/channels/*/messages/*/bindings/kafka/key': { add: 'breaking', remove: 'breaking', edit: 'breaking' },
  '/channels/*/messages/*/bindings/kafka/key/type': { add: 'breaking', remove: 'breaking', edit: 'breaking' },
};

// Unclassified paths nobody needs to look at: payloads (the registry's job),
// examples, docs, and the copies the parser makes when it resolves $refs.
const IGNORED = /\/(payload|examples|description|summary|title)(\/|$)|^\/components\/|^\/operations\/[^/]+\/(channel|messages)\//;

const load = async (f) => {
  const { document, diagnostics } = await fromFile(new Parser(), f).parse();
  if (!document) throw new Error(`cannot parse ${f}: ${diagnostics.filter((d) => d.severity === 0).map((d) => d.message).join('; ')}`);
  return document.json();
};

(async () => {
  const out = diff(await load(baseFile), await load(headFile), { override: OVERRIDES });
  const show = (label, changes) => changes.forEach((c) => console.log(`${label}  ${c.action} ${c.path}`));
  const breaking = out.breaking();
  const review = out.unclassified().filter((c) => !IGNORED.test(c.path));
  show('BREAKING    ', breaking);
  show('non-breaking', out.nonBreaking());
  show('review      ', review);
  if (breaking.length) {
    console.log(`${breaking.length} breaking change(s). Existing consumers would miss or misread events.`);
    console.log('Keep the old topic and operation, and publish the change as a new major version on a new topic (orders/v2/... on MQTT, orders.order-created.v2 on Kafka).');
    process.exit(1);
  }
  console.log('No structural breaking changes.');
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
