const ERROR_RULES = [
  [/is not reachable from trigger/i, 'WORKFLOW.VALIDATION.NOT_REACHABLE'],
  [/must have at least one outbound connection/i, 'WORKFLOW.VALIDATION.NO_OUTBOUND'],
  [
    /Condition node has invalid filter configuration/i,
    'WORKFLOW.VALIDATION.INVALID_CONDITION',
  ],
  [
    /Condition edges must use sourceHandle/i,
    'WORKFLOW.VALIDATION.CONDITION_BRANCHES',
  ],
  [
    /Wait for reply edges must use sourceHandle/i,
    'WORKFLOW.VALIDATION.WAIT_REPLY_BRANCHES',
  ],
  [/WhatsApp action requires an inbox/i, 'WORKFLOW.VALIDATION.WHATSAPP_INBOX'],
  [
    /WhatsApp action requires a phone number/i,
    'WORKFLOW.VALIDATION.WHATSAPP_PHONE_REQUIRED',
  ],
  [
    /WhatsApp action phone number is invalid/i,
    'WORKFLOW.VALIDATION.WHATSAPP_PHONE_INVALID',
  ],
  [/WhatsApp action inbox not found/i, 'WORKFLOW.VALIDATION.WHATSAPP_INBOX_NOT_FOUND'],
  [
    /WhatsApp action requires a WhatsApp/i,
    'WORKFLOW.VALIDATION.WHATSAPP_INBOX_TYPE',
  ],
  [/Invalid action:/i, 'WORKFLOW.VALIDATION.INVALID_ACTION'],
  [/Invalid trigger event:/i, 'WORKFLOW.VALIDATION.INVALID_TRIGGER'],
  [/Invalid wait unit:/i, 'WORKFLOW.VALIDATION.INVALID_WAIT_UNIT'],
  [/Wait duration must be between/i, 'WORKFLOW.VALIDATION.INVALID_WAIT_DURATION'],
  [/Invalid wait responder:/i, 'WORKFLOW.VALIDATION.INVALID_WAIT_RESPONDER'],
  [/deactivate.*edit|desative.*editar/i, 'WORKFLOW.VALIDATION.DEACTIVATE_TO_EDIT'],
  [/Graph contains a cycle/i, 'WORKFLOW.VALIDATION.CYCLE'],
  [
    /Graph must have exactly one trigger node/i,
    'WORKFLOW.VALIDATION.TRIGGER_COUNT',
  ],
  [/Edges cannot connect into the trigger/i, 'WORKFLOW.VALIDATION.TRIGGER_INBOUND'],
  [/AI outreach node requires a prompt/i, 'WORKFLOW.VALIDATION.AI_PROMPT'],
  [
    /AI prompt exceeds maximum length/i,
    'WORKFLOW.VALIDATION.AI_PROMPT_TOO_LONG',
  ],
  [
    /inteligencia_artificial feature/i,
    'WORKFLOW.VALIDATION.AI_FEATURE_REQUIRED',
  ],
  [/Invalid node type:/i, 'WORKFLOW.VALIDATION.INVALID_NODE_TYPE'],
  [/Edge missing source or target/i, 'WORKFLOW.VALIDATION.EDGE_INCOMPLETE'],
  [/Edge references unknown node/i, 'WORKFLOW.VALIDATION.EDGE_UNKNOWN_NODE'],
  [/Maximum .* send_message actions/i, 'WORKFLOW.VALIDATION.MAX_SEND_MESSAGES'],
  [/Maximum .* wait nodes/i, 'WORKFLOW.VALIDATION.MAX_WAIT_NODES'],
];

export const humanizeValidationError = (message, t) => {
  const text = (message || '').trim();
  if (!text) return t('WORKFLOW.VALIDATION.GENERIC');

  const rule = ERROR_RULES.find(([pattern]) => pattern.test(text));
  return rule ? t(rule[1]) : t('WORKFLOW.VALIDATION.GENERIC');
};
