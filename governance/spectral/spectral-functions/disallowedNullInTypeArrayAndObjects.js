function testType(type, context) {
  if (Array.isArray(type)) {
    if (type.includes('null') || type.includes(null)) {
      return [
        {
          message: `Property at path '${context.path.join('.')}' includes 'null' in its type array: []. This is disallowed.`,
          path: context.path
        },
      ];
    }
  }

  if (typeof type === 'string' && type === 'null') {
    return [
      {
        message: `Property at path '${context.path.join('.')}' includes 'null' in its type array: []. This is disallowed.`,
        path: context.path
      },
    ];
  }

  if (typeof type === 'object' && type === null) {
    return [
      {
        message: `Property at path '${context.path.join('.')}' includes 'null' in its type array: []. This is disallowed.`,
        path: context.path
      },
    ];
  }
  
}

export default function (targetVal, _options = undefined, context) {
  if (!targetVal || typeof targetVal !== 'object') {
    return [];
  }

  let result;
  const { type } = targetVal;

  result = testType(type, context);

  if (targetVal.items) {
    const itemsType = targetVal.items.type;
    result = testType(itemsType, context);
  }

  if (targetVal.properties) {
    Object.entries(targetVal.properties).forEach(([key, value]) => {
      if (value.type) {
        result = testType(value.type, context);
      }
    })
    result = [];
  }

  return result;
}

