import {
  buildWhatsAppProcessedParams,
  findComponentByType,
  hasMediaHeader,
  getMediaType,
  processVariable,
  replaceVariablesInMessage,
  renderTemplatePreview,
} from '@chatwoot/utils';

export {
  COMPONENT_TYPES,
  MEDIA_FORMATS,
  buildWhatsAppProcessedParams,
  extractVariables,
  findComponentByType,
  getMediaType,
  hasMediaHeader,
  isSendableTemplate,
  isWhatsAppComplete,
  processVariable,
  renderTemplatePreview,
} from '@chatwoot/utils';

export const DEFAULT_LANGUAGE = 'en';
export const DEFAULT_CATEGORY = 'UTILITY';

export const getHeaderMediaFormat = template => {
  const format = getMediaType(template);
  return format ? format.toUpperCase() : null;
};

export const getHeaderMediaBadgeLabel = template => getHeaderMediaFormat(template);

export const requiresDynamicMediaUrl = template => hasMediaHeader(template);

export const shouldUseEnhancedTemplateFormat = template => {
  const params = buildWhatsAppProcessedParams(template);
  return Boolean(params.body || params.header || params.buttons);
};

export const buildTemplateParameters = template =>
  buildWhatsAppProcessedParams(template);

export const isValidPublicMediaUrl = url => {
  if (!url || typeof url !== 'string') return false;

  try {
    const parsed = new URL(url.trim());
    return ['http:', 'https:'].includes(parsed.protocol);
  } catch {
    return false;
  }
};

export const allKeysRequired = value => {
  if (!value || typeof value !== 'object') return true;

  if (Array.isArray(value)) {
    return value.every(item => {
      if (!item) return true;
      if (item.type === 'url' || item.type === 'copy_code') {
        return Boolean(item.parameter && item.parameter.trim());
      }
      return true;
    });
  }

  return Object.keys(value).every(key => {
    if (key === 'media_type') return true;

    const entry = value[key];
    if (Array.isArray(entry)) {
      return allKeysRequired(entry);
    }
    if (entry && typeof entry === 'object') {
      return allKeysRequired(entry);
    }
    if (key === 'media_url') {
      return isValidPublicMediaUrl(entry);
    }

    return Boolean(entry && String(entry).trim());
  });
};

export const replaceTemplateVariables = (templateText, processedParams) =>
  renderTemplatePreview(templateText, processedParams.body || processedParams);

export const interpolateParamsValues = (params, variables = {}) => {
  if (typeof params === 'string') {
    return replaceVariablesInMessage({ message: params, variables });
  }

  if (Array.isArray(params)) {
    return params.map(entry => interpolateParamsValues(entry, variables));
  }

  if (params && typeof params === 'object') {
    return Object.fromEntries(
      Object.entries(params).map(([key, value]) => [
        key,
        key === 'media_type' ? value : interpolateParamsValues(value, variables),
      ])
    );
  }

  return params;
};

export const getTextHeaderVariables = template => {
  const header = findComponentByType(template, 'HEADER');
  if (header?.format !== 'TEXT' || !header.text) return [];

  const matches = header.text.match(/{{([^}]+)}}/g) || [];
  return matches.map(variable => processVariable(variable));
};
