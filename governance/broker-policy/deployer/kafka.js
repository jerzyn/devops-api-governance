'use strict';

/**
 * Applies a Kafka broker policy (see generate-policy.js) with the Kafka admin
 * API, as the super user:
 *
 *   topics   created when missing; partitions only ever grow (Kafka cannot
 *            shrink them); topic configuration set to what the contract says
 *   ACLs     made equal to the policy for every account it lists, plus any
 *            account a previous policy listed: missing ACLs are created,
 *            ACLs no longer in the policy are deleted. Unchanged ACLs are
 *            never touched, so running clients keep working.
 */

const {
  Kafka, logLevel, AclResourceTypes, AclOperationTypes, AclPermissionTypes, ResourcePatternTypes,
  ConfigResourceTypes,
} = require('kafkajs');

const BROKERS = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
const ADMIN = process.env.KAFKA_ADMIN_USER || 'admin';
const ADMIN_PW = process.env.KAFKA_ADMIN_PASSWORD || 'admin-pw';
const PROTECTED = new Set([`User:${ADMIN}`]);

const T = AclResourceTypes;
const O = AclOperationTypes;

// The ACLs one account needs, as plain objects.
function desiredAcls(account, grants) {
  const principal = `User:${account}`;
  const acl = (resourceType, resourceName, operation, patternType = ResourcePatternTypes.LITERAL) => ({
    resourceType, resourceName, resourcePatternType: patternType, principal, host: '*',
    operation, permissionType: AclPermissionTypes.ALLOW,
  });
  const out = [];
  for (const t of grants.publish || []) out.push(acl(T.TOPIC, t, O.WRITE), acl(T.TOPIC, t, O.DESCRIBE));
  for (const t of grants.subscribe || []) out.push(acl(T.TOPIC, t, O.READ), acl(T.TOPIC, t, O.DESCRIBE));
  for (const g of grants.groups || []) out.push(acl(T.GROUP, g, O.READ));
  for (const g of grants.groupPrefix || []) out.push(acl(T.GROUP, g, O.READ, ResourcePatternTypes.PREFIXED));
  for (const p of grants.publishPrefix || []) {
    for (const op of [O.WRITE, O.CREATE, O.DESCRIBE]) out.push(acl(T.TOPIC, p, op, ResourcePatternTypes.PREFIXED));
  }
  return out;
}

const key = (a) => [a.principal, a.resourceType, a.resourceName, a.resourcePatternType, a.operation, a.permissionType, a.host].join('|');

async function apply(policy, previous) {
  const kafka = new Kafka({
    clientId: 'broker-policy-deployer',
    brokers: BROKERS,
    sasl: { mechanism: 'plain', username: ADMIN, password: ADMIN_PW },
    logLevel: logLevel.WARN,
  });
  const admin = kafka.admin();
  await admin.connect();
  const changes = [];
  try {
    // Topics.
    const existing = new Set(await admin.listTopics());
    const missing = (policy.topics || []).filter((t) => !existing.has(t.name));
    if (missing.length) {
      await admin.createTopics({
        waitForLeaders: true,
        topics: missing.map((t) => ({
          topic: t.name,
          numPartitions: t.partitions,
          replicationFactor: t.replicas,
          configEntries: Object.entries(t.config || {}).map(([name, value]) => ({ name, value })),
        })),
      });
      missing.forEach((t) => changes.push(`created topic ${t.name} (${t.partitions} partitions)`));
    }
    const present = (policy.topics || []).filter((t) => existing.has(t.name));
    if (present.length) {
      const meta = await admin.fetchTopicMetadata({ topics: present.map((t) => t.name) });
      const grow = present.filter((t) => {
        const m = meta.topics.find((x) => x.name === t.name);
        return m && t.partitions > m.partitions.length;
      });
      if (grow.length) {
        await admin.createPartitions({ topicPartitions: grow.map((t) => ({ topic: t.name, count: t.partitions })) });
        grow.forEach((t) => changes.push(`grew ${t.name} to ${t.partitions} partitions`));
      }
      const withConfig = present.filter((t) => Object.keys(t.config || {}).length);
      if (withConfig.length) {
        await admin.alterConfigs({
          validateOnly: false,
          resources: withConfig.map((t) => ({
            type: ConfigResourceTypes.TOPIC,
            name: t.name,
            configEntries: Object.entries(t.config).map(([name, value]) => ({ name, value })),
          })),
        });
      }
    }

    // ACLs: desired vs. current, for every account this or the previous
    // policy manages.
    const desired = Object.entries(policy.clients).flatMap(([a, g]) => desiredAcls(a, g));
    const managed = new Set([
      ...Object.keys(policy.clients), ...Object.keys(previous?.clients || {}),
    ].map((a) => `User:${a}`).filter((p) => !PROTECTED.has(p)));

    const { resources } = await admin.describeAcls({
      resourceType: T.ANY, resourcePatternType: ResourcePatternTypes.ANY,
      operation: O.ANY, permissionType: AclPermissionTypes.ANY,
    });
    const current = resources.flatMap((r) => r.acls.map((a) => ({
      resourceType: r.resourceType, resourceName: r.resourceName, resourcePatternType: r.resourcePatternType,
      principal: a.principal, host: a.host, operation: a.operation, permissionType: a.permissionType,
    }))).filter((a) => managed.has(a.principal));

    const want = new Set(desired.map(key));
    const have = new Set(current.map(key));
    const toCreate = desired.filter((a) => !have.has(key(a)));
    const toDelete = current.filter((a) => !want.has(key(a)));
    if (toCreate.length) await admin.createAcls({ acl: toCreate });
    if (toDelete.length) await admin.deleteAcls({ filters: toDelete });
    if (toCreate.length) changes.push(`${toCreate.length} ACL(s) added`);
    if (toDelete.length) changes.push(`${toDelete.length} ACL(s) removed`);
    return { errors: [], warnings: [], changes };
  } finally {
    await admin.disconnect();
  }
}

module.exports = { apply, desiredAcls };
