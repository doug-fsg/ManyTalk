// Extensions to workflow constants for the forms feature.
// Exported separately so base constants.js (read-only) is not modified.
import { WORKFLOW_TRIGGER_EVENTS as BASE_TRIGGER_EVENTS } from './constants';

export const WORKFLOW_TRIGGER_EVENTS_EXTENDED = [
  ...BASE_TRIGGER_EVENTS,
  { key: 'form_submitted', value: 'Formulário enviado' },
];
