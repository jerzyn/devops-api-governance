export default function checkTableNamePlural(input, options, context) {
  const errors = [];
  
  if (!isPlural(input)) {
    errors.push({
      message: `Array collection property '${input}' SHOULD be plural. https://api-guidelines.app.pzu.pl/general-guidelines/#json-pzugeneral112025-json`,
      path: context.path
    });
  }
  return errors;
}

function isPlural(word) {
  if (!word || typeof word !== 'string') return false;

  const irregularPlurals = {
    'child': 'children',
    'foot': 'feet', 
    'tooth': 'teeth',
    'mouse': 'mice',
    'person': 'people',
    'man': 'men',
    'woman': 'women'
  };
  const lowerWord = word.toLowerCase();
  // Check irregular plurals
  if (Object.values(irregularPlurals).includes(lowerWord)) {
    return true;
  }
  // Check common plural patterns
  return (
    lowerWord.endsWith('s') && !lowerWord.endsWith('ss') ||
    lowerWord.endsWith('es') ||
    lowerWord.endsWith('ies') ||
    lowerWord.endsWith('ves') ||
    lowerWord.endsWith('en') && lowerWord !== 'open'
  );
}

