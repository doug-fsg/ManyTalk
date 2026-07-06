// Extensions to workflow constants for the forms feature.
// Exported separately so base constants.js (read-only) is not modified.
import { WORKFLOW_TRIGGER_EVENTS as BASE_TRIGGER_EVENTS } from './constants';

export const FORM_SUBMITTED_EVENT_KEY = 'form_submitted';
export const FORM_SUBMITTED_FORM_CONDITION_KEY = 'account_form_id';

export const WORKFLOW_TRIGGER_EVENTS_EXTENDED = [
  ...BASE_TRIGGER_EVENTS,
  { key: FORM_SUBMITTED_EVENT_KEY, value: 'Formulário enviado' },
];

export const TRIGGER_EVENT_LABELS = {
  [FORM_SUBMITTED_EVENT_KEY]: 'Formulário enviado',
};

export const buildFormSubmittedAutomationTypes = () => ({
  [FORM_SUBMITTED_EVENT_KEY]: { conditions: [], actions: [] },
});

export const extractFormIdsFromConditions = (conditions = []) => {
  const match = (conditions || []).find(
    condition =>
      condition.attribute_key === FORM_SUBMITTED_FORM_CONDITION_KEY &&
      condition.filter_operator === 'equal_to'
  );
  if (!match) return [];
  return (match.values || []).map(value => String(value));
};

export const buildFormSubmittedConditions = formIds => {
  const ids = (formIds || []).map(id => String(id)).filter(Boolean);
  if (!ids.length) return [];
  return [
    {
      attribute_key: FORM_SUBMITTED_FORM_CONDITION_KEY,
      filter_operator: 'equal_to',
      values: ids,
      custom_attribute_type: '',
    },
  ];
};
