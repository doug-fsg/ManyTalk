import { replaceVariablesInMessage } from '@chatwoot/utils';

export const COMPONENT_TYPES = {
  HEADER: 'HEADER',
  BODY: 'BODY',
  BUTTONS: 'BUTTONS',
};

export const MEDIA_FORMATS = ['IMAGE', 'VIDEO', 'DOCUMENT'];

export const findComponentByType = (template, type) =>
  template.components?.find(component => component.type === type);

export const processVariable = str => {
  return str.replace(/{{|}}/g, '');
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

  const keys = Object.keys(value);
  return keys.every(key => {
    if (key === 'media_type') return true;
    return value[key];
  });
};

export const replaceTemplateVariables = (templateText, processedParams) => {
  const bodyParams = processedParams.body || processedParams;

  return templateText.replace(/{{([^}]+)}}/g, (match, variable) => {
    const variableKey = processVariable(variable);
    return bodyParams[variableKey] || `{{${variable}}}`;
  });
};

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

export const hasMediaHeader = template => {
  const headerComponent = findComponentByType(template, COMPONENT_TYPES.HEADER);
  return (
    headerComponent &&
    MEDIA_FORMATS.includes(headerComponent.format?.toUpperCase())
  );
};

export const buildTemplateParameters = (template, includeMediaHeader = false) => {
  const allVariables = {};

  const bodyComponent = findComponentByType(template, COMPONENT_TYPES.BODY);
  const headerComponent = findComponentByType(template, COMPONENT_TYPES.HEADER);

  if (bodyComponent?.text) {
    const matchedVariables = bodyComponent.text.match(/{{([^}]+)}}/g);
    if (matchedVariables) {
      allVariables.body = {};
      matchedVariables.forEach(variable => {
        const key = processVariable(variable);
        allVariables.body[key] = '';
      });
    }
  }

  if (includeMediaHeader && hasMediaHeader(template)) {
    allVariables.header = {
      media_url: '',
      media_type: headerComponent.format.toLowerCase(),
    };

    if (headerComponent.format.toLowerCase() === 'document') {
      allVariables.header.media_name = '';
    }
  }

  const buttonComponents = template.components?.filter(
    component => component.type === COMPONENT_TYPES.BUTTONS
  );

  buttonComponents?.forEach(buttonComponent => {
    buttonComponent.buttons?.forEach((button, index) => {
      if (button.type === 'URL' && button.url && button.url.includes('{{')) {
        if (!allVariables.buttons) allVariables.buttons = [];
        allVariables.buttons[index] = {
          type: 'url',
          parameter: '',
          url: button.url,
        };
      }

      if (button.type === 'COPY_CODE') {
        if (!allVariables.buttons) allVariables.buttons = [];
        allVariables.buttons[index] = {
          type: 'copy_code',
          parameter: '',
        };
      }
    });
  });

  return allVariables;
};

export const buildLegacyTemplateParameters = template => {
  const bodyComponent = findComponentByType(template, COMPONENT_TYPES.BODY);
  if (!bodyComponent?.text) return {};

  const matchedVariables = bodyComponent.text.match(/{{([^}]+)}}/g);
  if (!matchedVariables) return {};

  return matchedVariables.reduce((acc, variable) => {
    const key = processVariable(variable);
    acc[key] = '';
    return acc;
  }, {});
};
