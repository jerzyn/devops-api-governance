export default function (targetVal, _options = undefined, context) {
  if (!targetVal || typeof targetVal !== 'object') {
    return [];
  }
  const { type } = targetVal;
  const [ typeDef ] = type;
  if (Array.isArray(type) && (type.includes('null') || type.includes(null))) {
    return [
      {
        message: `Property at path '${context.path.join('.')}' is a ${typeDef} but includes 'null' in its type array: [${type.join(', ')}]. This is disallowed.`,
        path: context.path
      },
    ];
  }

  return [];
}

