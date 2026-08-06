import { workflowActionLabel } from 'dashboard/routes/dashboard/settings/workflows/workflowActionHelpers';

const NODE_TYPE_LABEL_KEYS = {
  trigger: 'WORKFLOW.EDITOR.NODE_TRIGGER',
  wait: 'WORKFLOW.EDITOR.NODE_WAIT',
  wait_for_reply: 'WORKFLOW.EDITOR.NODE_WAIT_FOR_REPLY',
  condition: 'WORKFLOW.EDITOR.NODE_CONDITION',
  action: 'WORKFLOW.EDITOR.NODE_ACTION',
  ai_outreach: 'WORKFLOW.EDITOR.NODE_CALL_CLIENT',
  ai_conversation_analysis: 'WORKFLOW.EDITOR.NODE_CONVERSATION_ANALYSIS',
  ai_wait_for_intent: 'WORKFLOW.EDITOR.NODE_AI_WAIT_FOR_INTENT',
};

const TIMELINE_STATUS_KEYS = {
  completed: 'WORKFLOW.REGUA.TIMELINE.COMPLETED',
  running: 'WORKFLOW.REGUA.TIMELINE.RUNNING',
  scheduled: 'WORKFLOW.REGUA.TIMELINE.SCHEDULED',
  pending: 'WORKFLOW.REGUA.TIMELINE.PENDING',
  failed: 'WORKFLOW.REGUA.TIMELINE.FAILED',
  skipped: 'WORKFLOW.REGUA.TIMELINE.SKIPPED',
};

const isTechnicalKey = value => /^[a-z][a-z0-9_]*$/.test(String(value || ''));

/**
 * Label for conversation header / régua timeline.
 * Prefers API human label; falls back to action/node i18n for raw keys.
 */
export const displayWorkflowStepLabel = (item, t) => {
  if (!item) return '—';
  const label = (item.label || '').trim();
  const type = item.type || item.node_type || '';

  if (label && !isTechnicalKey(label)) return label;

  if (label) {
    const actionLabel = workflowActionLabel(label);
    if (actionLabel !== label) return actionLabel;
  }

  const typeKey = NODE_TYPE_LABEL_KEYS[type] || NODE_TYPE_LABEL_KEYS[label];
  if (typeKey && typeof t === 'function') return t(typeKey);

  return label || type || '—';
};

export const displayTimelineStatus = (status, t) => {
  if (!status) return '';
  const key = TIMELINE_STATUS_KEYS[status];
  if (key && typeof t === 'function') return t(key);
  return status;
};
