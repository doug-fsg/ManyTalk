import filterQueryGenerator from './filterQueryGenerator';
import { getDefaultConditions } from './automationHelper';

const hasConditionValues = condition => {
  const values = condition.values;
  if (Array.isArray(values)) return values.length > 0;
  if (values && typeof values === 'object' && values.id != null) return true;
  return values != null && String(values).trim() !== '';
};

/**
 * @param {Object} [options]
 * @param {boolean} [options.dropEmpty=false] — true ao salvar o fluxo (remove linhas incompletas)
 */
export const serializeWorkflowConditions = (conditions, options = {}) => {
  const { dropEmpty = false } = options;
  if (!conditions || !conditions.length) return [];
  const copy = JSON.parse(JSON.stringify(conditions));
  const payload = filterQueryGenerator(copy).payload;
  if (dropEmpty) return payload.filter(hasConditionValues);
  return payload;
};

export const defaultConditionsForEvent = eventName => {
  const event = eventName || 'conversation_created';
  return JSON.parse(JSON.stringify(getDefaultConditions(event)));
};
