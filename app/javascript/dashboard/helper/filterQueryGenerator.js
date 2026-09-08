import { extractAttributeValueLabel } from 'shared/helpers/formFieldHelpers';

const serializeFilterValue = value => {
  if (value == null) return value;
  if (typeof value !== 'object') return value;
  if (value.id != null && typeof value.id !== 'object') return value.id;
  const label = extractAttributeValueLabel(value);
  return label != null ? label : value;
};

const setArrayValues = item => {
  if (item.values[0] && typeof item.values[0] === 'object') {
    return item.values.map(val => serializeFilterValue(val));
  }
  return item.values;
};

const contentValuesToArray = values => {
  if (Array.isArray(values)) {
    return values.map(v => serializeFilterValue(v));
  }
  if (values && typeof values === 'object') {
    const serialized = serializeFilterValue(values);
    return serialized != null && serialized !== '' ? [serialized] : [];
  }
  const text = values == null ? '' : String(values);
  return text
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
};

const generateValues = item => {
  if (item.attribute_key === 'content') {
    return contentValuesToArray(item.values);
  }
  if (Array.isArray(item.values)) {
    return setArrayValues(item);
  }
  if (typeof item.values === 'object') {
    const serialized = serializeFilterValue(item.values);
    return serialized != null && serialized !== '' ? [serialized] : [];
  }
  if (!item.values) {
    return [];
  }
  return [item.values];
};

const generatePayload = data => {
  // Make a copy of data to avoid vue data reactivity issues
  const filters = JSON.parse(JSON.stringify(data));
  let payload = filters.map(item => {
    // If item key is content, we will split it using comma and return as array
    // FIX ME: Make this generic option instead of using the key directly here
    item.values = generateValues(item);
    return item;
  });

  // For every query added, the query_operator is set default to and so the
  // last query will have an extra query_operator, this would break the api.
  // Setting this to null for all query payload
  payload[payload.length - 1].query_operator = undefined;
  return { payload };
};

export default generatePayload;
