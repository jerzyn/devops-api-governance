export default function (targetVal, opts, context) {
  if (typeof targetVal !== 'string') return [];
  // Extract all {variable} segments
  const matches = targetVal.match(/\{([^}]+)\}/g);
  if (!matches) return;
  const errors = [];
  for (const match of matches) {
    const varName = match.slice(1, -1); // remove {}
    // Only allow ALPHA, DIGIT, underscore, percent-encoded
    if (!/^[A-Za-z0-9_]+(?:%[A-Fa-f0-9]{2})*$/.test(varName)) {
      errors.push({
        message: `URI template variable name '${varName}' must only use letters, digits, underscore (_), or percent-encoded characters. Hyphens (-) are NOT allowed (RFC6570).`,
        path: context.path,
      });
    }
  }
  return errors.length ? errors : [];
};

