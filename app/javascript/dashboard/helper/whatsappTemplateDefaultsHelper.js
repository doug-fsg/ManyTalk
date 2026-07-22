const UI_SETTINGS_KEY = 'whatsapp_template_defaults';

const isPlainObject = value =>
  value !== null && typeof value === 'object' && !Array.isArray(value);

export const buildTemplateDefaultsKey = template => {
  const name = template?.name || '';
  const language = template?.language || '';
  return `${name}:${language}`;
};

export const getSavedTemplateDefaults = (uiSettings, template) => {
  const key = buildTemplateDefaultsKey(template);
  return uiSettings?.[UI_SETTINGS_KEY]?.[key] || null;
};

export const applySavedTemplateDefaults = (baseParams, savedDefaults) => {
  if (!savedDefaults) {
    return baseParams;
  }

  return mergeTemplateDefaults(baseParams, savedDefaults);
};

export const buildTemplateDefaultsSettingsUpdate = (
  uiSettings,
  template,
  processedParams
) => {
  const sanitized = sanitizeTemplateDefaultsForSave(processedParams);
  if (!sanitized) {
    return null;
  }

  const key = buildTemplateDefaultsKey(template);

  return {
    [UI_SETTINGS_KEY]: {
      ...(uiSettings?.[UI_SETTINGS_KEY] || {}),
      [key]: sanitized,
    },
  };
};

const mergeTemplateDefaults = (base, saved) => {
  if (typeof saved === 'string') {
    return saved.trim() ? saved : base;
  }

  if (Array.isArray(base)) {
    if (!Array.isArray(saved)) {
      return base;
    }

    return base.map((item, index) => {
      if (saved[index] === undefined) {
        return item;
      }

      return mergeTemplateDefaults(item, saved[index]);
    });
  }

  if (!isPlainObject(base) || !isPlainObject(saved)) {
    return base;
  }

  const merged = { ...base };

  Object.keys(base).forEach(key => {
    if (!(key in saved)) {
      return;
    }

    merged[key] = mergeTemplateDefaults(base[key], saved[key]);
  });

  return merged;
};

const sanitizeTemplateDefaultsForSave = params => {
  if (params == null) {
    return undefined;
  }

  if (typeof params === 'string') {
    const trimmed = params.trim();
    return trimmed || undefined;
  }

  if (Array.isArray(params)) {
    const items = params
      .map(item => sanitizeTemplateDefaultsForSave(item))
      .map((item, index) => item ?? null);

    return items.some(item => item !== null) ? items : undefined;
  }

  if (!isPlainObject(params)) {
    return undefined;
  }

  const result = {};

  Object.entries(params).forEach(([key, value]) => {
    if (key === 'media_type') {
      result[key] = value;
      return;
    }

    const sanitized = sanitizeTemplateDefaultsForSave(value);
    if (sanitized !== undefined) {
      result[key] = sanitized;
    }
  });

  return Object.keys(result).length ? result : undefined;
};
