'use strict';

/**
 * broker-policy-deployer: receives a broker policy generated from an AsyncAPI
 * contract and the catalog (governance/broker-policy/generate-policy.js),
 * checks it and applies it to Mosquitto through the dynamic security
 * plugin's $CONTROL API.
 *
 *   POST /deploy   body: the policy JSON -> 200 {status: "applied", ...}
 *   GET  /policy   the policy applied last
 *   GET  /health
 *
 * Every account in the policy gets one role, "api-policy-<account>", with
 * exactly the topics the policy lists. All commands go to the broker in one
 * $CONTROL message, which Mosquitto handles in one go: clients never see a
 * half-applied policy. Roles of accounts the new policy no longer lists are
 * deleted, so their access ends.
 */

const http = require('http');
const mqtt = require('mqtt');

const PORT = Number(process.env.PORT) || 9100;
const BROKER = process.env.BROKER_URL || 'mqtt://mosquitto:1883';
const ADMIN = process.env.BROKER_ADMIN_USER || 'policy-admin';
const ADMIN_PW = process.env.BROKER_ADMIN_PASSWORD || 'policy-admin-pw';
const CONTROL = '$CONTROL/dynamic-security/v1';
const ROLE_PREFIX = 'api-policy-';
const MAX_BODY = 256 * 1024;

let current = null;

// MQTT topic filter: levels separated by '/', '+' alone in a level, '#' last.
const validFilter = (t) => typeof t === 'string' && t.length > 0
  && t.split('/').every((lvl, i, all) => (lvl === '#' ? i === all.length - 1 : !/[+#]/.test(lvl) || lvl === '+'));

// Returns a list of problems; empty when the policy can be applied.
function check(policy) {
  if (!policy || typeof policy !== 'object' || !policy.clients || typeof policy.clients !== 'object') {
    return ['policy must be an object with "clients"'];
  }
  const problems = [];
  for (const [name, grants] of Object.entries(policy.clients)) {
    if (!/^[A-Za-z0-9._-]+$/.test(name)) problems.push(`account name not allowed: ${name}`);
    for (const key of ['publish', 'subscribe']) {
      for (const t of grants[key] || []) if (!validFilter(t)) problems.push(`${name}: invalid ${key} topic ${t}`);
    }
  }
  return problems;
}

// One $CONTROL request: send the commands, wait for the matching response.
function control(commands) {
  return new Promise((resolve, reject) => {
    const client = mqtt.connect(BROKER, {
      clientId: `broker-policy-deployer-${Date.now()}`,
      username: ADMIN,
      password: ADMIN_PW,
      reconnectPeriod: 0,
      connectTimeout: 5000,
    });
    const timer = setTimeout(() => { client.end(true); reject(new Error('no answer from the broker')); }, 10000);
    client.once('error', (err) => { clearTimeout(timer); client.end(true); reject(err); });
    client.once('connect', () => {
      client.subscribe(`${CONTROL}/response`, { qos: 1 }, (err) => {
        if (err) return reject(err);
        client.publish(CONTROL, JSON.stringify({ commands }), { qos: 1 });
      });
    });
    client.on('message', (_topic, payload) => {
      clearTimeout(timer);
      client.end();
      resolve(JSON.parse(payload.toString()).responses || []);
    });
  });
}

async function apply(policy) {
  const [listed] = await control([{ command: 'listRoles' }]);
  const existing = (listed.data?.roles || []).filter((r) => r.startsWith(ROLE_PREFIX));
  const wanted = Object.keys(policy.clients).map((c) => ROLE_PREFIX + c);

  const commands = [];
  for (const role of existing) commands.push({ command: 'deleteRole', rolename: role });
  for (const [account, grants] of Object.entries(policy.clients)) {
    const rolename = ROLE_PREFIX + account;
    const acls = [
      ...(grants.publish || []).map((topic) => ({ acltype: 'publishClientSend', topic, allow: true })),
      ...(grants.subscribe || []).map((topic) => ({ acltype: 'subscribePattern', topic, allow: true })),
    ];
    commands.push({ command: 'createRole', rolename, acls });
    commands.push({ command: 'addClientRole', username: account, rolename });
  }
  const responses = await control(commands);

  // A missing account is a warning (in the catalog, no broker account yet);
  // anything else is an error.
  const warnings = [];
  const errors = [];
  responses.forEach((r, i) => {
    if (!r.error) return;
    const cmd = commands[i];
    if (cmd.command === 'addClientRole' && /not found/i.test(r.error)) {
      warnings.push(`no broker account "${cmd.username}": it gets no access`);
    } else {
      errors.push(`${cmd.command} ${cmd.rolename || ''}: ${r.error}`);
    }
  });
  const removed = existing.filter((r) => !wanted.includes(r)).map((r) => r.slice(ROLE_PREFIX.length));
  return { errors, warnings, removed };
}

const send = (res, status, body) => {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
};

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') return send(res, 200, { status: 'ok' });
  if (req.method === 'GET' && req.url === '/policy') return send(res, current ? 200 : 404, current || { error: 'no policy applied yet' });

  if (req.method === 'POST' && req.url === '/deploy') {
    let body = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > MAX_BODY) req.destroy();
    });
    req.on('end', async () => {
      let policy;
      try { policy = JSON.parse(body); } catch { return send(res, 400, { error: 'body is not JSON' }); }
      const problems = check(policy);
      if (problems.length) return send(res, 400, { error: 'invalid policy', problems });
      try {
        const { errors, warnings, removed } = await apply(policy);
        if (errors.length) return send(res, 502, { error: 'the broker rejected the policy', errors });
        current = policy;
        console.log(`applied policy for ${policy.api} ${policy.version}`);
        return send(res, 200, { status: 'applied', api: policy.api, version: policy.version, warnings, removed });
      } catch (err) {
        return send(res, 502, { error: err.message });
      }
    });
    return;
  }

  send(res, 404, { error: 'not found' });
});

if (require.main === module) {
  server.listen(PORT, () => console.log(`broker-policy-deployer on :${PORT}, broker ${BROKER}`));
}

module.exports = { check };
