/**
 * api-peak:async13:2026-open-payloads
 *
 * Walks a payload schema (nested properties, items, allOf/anyOf/oneOf) and
 * reports every `additionalProperties: false`, with the exact path, so the
 * finding points at the line that closes the schema.
 */
export default function openPayloadSchema(schema, _opts, context) {
  const results = [];
  const seen = new Set();

  const walk = (node, path) => {
    if (!node || typeof node !== 'object' || seen.has(node)) return;
    seen.add(node);
    if (node.additionalProperties === false) {
      results.push({
        message: 'Payload schema MUST NOT set additionalProperties: false.',
        path: [...path, 'additionalProperties'],
      });
    }
    for (const [name, sub] of Object.entries(node.properties || {})) {
      walk(sub, [...path, 'properties', name]);
    }
    if (node.items) walk(node.items, [...path, 'items']);
    if (node.additionalProperties && typeof node.additionalProperties === 'object') {
      walk(node.additionalProperties, [...path, 'additionalProperties']);
    }
    for (const key of ['allOf', 'anyOf', 'oneOf']) {
      (node[key] || []).forEach((sub, i) => walk(sub, [...path, key, i]));
    }
  };

  walk(schema, context.path);
  return results;
}
