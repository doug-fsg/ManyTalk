/** Display types supported on public forms (file upload excluded). */
export const FORM_SUPPORTED_DISPLAY_TYPES = [
  'text',
  'number',
  'currency',
  'percent',
  'link',
  'date',
  'list',
  'checkbox',
];

const DISPLAY_TYPE_BY_ID = {
  0: 'text',
  1: 'number',
  2: 'currency',
  3: 'percent',
  4: 'link',
  5: 'date',
  6: 'list',
  7: 'checkbox',
  8: 'file',
};

export const normalizeDisplayType = type => {
  if (type === null || type === undefined || type === '') return null;
  if (typeof type === 'number') return DISPLAY_TYPE_BY_ID[type] || null;
  if (typeof type === 'string') {
    if (/^\d+$/.test(type) && DISPLAY_TYPE_BY_ID[Number(type)]) {
      return DISPLAY_TYPE_BY_ID[Number(type)];
    }
    return type;
  }
  return null;
};

export const getFieldDisplayType = field => {
  if (field?.type !== 'custom_attribute') return null;
  return normalizeDisplayType(field.attribute_display_type);
};

export const isFormSupportedAttribute = attr =>
  FORM_SUPPORTED_DISPLAY_TYPES.includes(normalizeDisplayType(attr?.attribute_display_type));

export const resolveFieldValueKey = field => {
  if (field?.type === 'custom_attribute') return field.key;
  return field?.field || field?.key;
};

export const extractAttributeValueLabel = item => {
  if (typeof item === 'string') return item;
  if (item && typeof item === 'object') {
    return item.name || item.label || item.value || null;
  }
  return item != null ? String(item) : null;
};

export const normalizeAttributeValues = values => {
  if (!values) return [];
  if (Array.isArray(values)) {
    return values.map(extractAttributeValueLabel).filter(Boolean);
  }
  if (typeof values === 'object') {
    const nested = values.stages || values.values || values.items;
    if (nested) return normalizeAttributeValues(nested);
    return Object.entries(values)
      .filter(([key]) => key !== 'permissions')
      .map(([key, data]) => (typeof data === 'object' ? key : extractAttributeValueLabel(data)))
      .filter(Boolean);
  }
  return [];
};

export const listOptionsFromField = field => {
  const values = field?.attribute_values || [];
  return normalizeAttributeValues(values);
};

export const isCheckboxField = field =>
  field?.type === 'custom_attribute' && getFieldDisplayType(field) === 'checkbox';

export const isListField = field =>
  field?.type === 'custom_attribute' && getFieldDisplayType(field) === 'list';

export const getFieldKind = field => {
  if (isCheckboxField(field)) return 'checkbox';
  if (isListField(field)) return 'list';
  if (field?.field === 'phone_number' || field?.key === 'phone_number') return 'phone';
  if (field?.field === 'email' || field?.key === 'email') return 'email';
  if (field?.field === 'name' || field?.key === 'name') return 'name';

  switch (getFieldDisplayType(field)) {
    case 'date':
      return 'date';
    case 'currency':
      return 'currency';
    case 'percent':
      return 'percent';
    case 'number':
      return 'number';
    case 'link':
      return 'link';
    default:
      return 'text';
  }
};

export const hasInputMask = field => {
  const kind = getFieldKind(field);
  return ['phone', 'currency', 'percent', 'number'].includes(kind);
};

export const fieldPlaceholderForField = field => {
  switch (getFieldKind(field)) {
    case 'phone':
      return '(11) 99999-9999';
    case 'email':
      return 'seu@email.com';
    case 'name':
      return 'Seu nome completo';
    case 'link':
      return 'https://exemplo.com';
    case 'currency':
      return '0,00';
    case 'percent':
      return '0';
    case 'number':
      return '0';
    default:
      return '';
  }
};

export const autocompleteForField = field => {
  switch (getFieldKind(field)) {
    case 'email':
      return 'email';
    case 'phone':
      return 'tel';
    case 'name':
      return 'name';
    default:
      return 'off';
  }
};

export const inputTypeForField = field => {
  if (field?.field === 'email' || field?.key === 'email') return 'email';
  if (field?.field === 'phone_number' || field?.key === 'phone_number') return 'tel';

  if (field?.type === 'custom_attribute') {
    switch (getFieldDisplayType(field)) {
      case 'currency':
      case 'percent':
      case 'number':
        return 'text';
      case 'link':
        return 'url';
      case 'date':
        return 'date';
      default:
        return 'text';
    }
  }

  return 'text';
};

export const inputModeForField = field => {
  const displayType = getFieldDisplayType(field);
  if (displayType === 'currency') return 'decimal';
  if (displayType === 'percent') return 'decimal';
  return undefined;
};

export const enrichCustomField = (field, contactAttributes = []) => {
  if (field?.type !== 'custom_attribute') return field;

  const attr = contactAttributes.find(a => a.attribute_key === field.attribute_key);
  if (!attr) return field;

  const displayType = normalizeDisplayType(
    field.attribute_display_type || attr.attribute_display_type
  );
  const dbValues = normalizeAttributeValues(attr.attribute_values);
  const savedValues = normalizeAttributeValues(field.attribute_values);
  const resolvedValues =
    displayType === 'list' || displayType === 'checkbox'
      ? dbValues.length
        ? dbValues
        : savedValues
      : normalizeAttributeValues(field.attribute_values ?? attr.attribute_values);

  return {
    ...field,
    attribute_display_type: displayType || field.attribute_display_type || attr.attribute_display_type,
    attribute_values: resolvedValues,
  };
};

export const enrichDefinitionFields = (fields, contactAttributes = []) =>
  (fields || []).map(field => {
    if (field?.type === 'custom_attribute' && contactAttributes.length) {
      return enrichCustomField(field, contactAttributes);
    }

    const displayType = field.attribute_display_type
      ? normalizeDisplayType(field.attribute_display_type) || field.attribute_display_type
      : field.attribute_display_type;

    return {
      ...field,
      attribute_display_type: displayType,
      attribute_values: field.attribute_values
        ? normalizeAttributeValues(field.attribute_values)
        : field.attribute_values,
    };
  });
