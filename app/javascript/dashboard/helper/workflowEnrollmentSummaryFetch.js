export const VISIBLE_ENROLLMENT_SUMMARY_LIMIT = 50;
export const IN_PROGRESS_ENROLLMENT_STATUSES = ['active', 'waiting', 'paused'];

export function visibleConversationIdsKey(conversations = []) {
  const ids = conversations
    .map(conversation => conversation.id)
    .slice(0, VISIBLE_ENROLLMENT_SUMMARY_LIMIT);

  return [...ids]
    .sort((left, right) => Number(left) - Number(right))
    .join(',');
}

export function shouldFetchEnrollmentSummaries(prevKey, nextKey) {
  return prevKey !== nextKey;
}

export function summaryFromCablePayload(payload) {
  if (!payload?.conversation_id) return null;

  const summary = {
    enrollment_id: payload.enrollment_id,
    workflow_id: payload.workflow_id,
    workflow_name: payload.workflow_name,
    status: payload.status,
    current_node_label: payload.current_node_label,
    current_node_type: payload.current_node_type,
  };

  if (payload.step_index != null && payload.total_steps != null) {
    summary.step_index = payload.step_index;
    summary.total_steps = payload.total_steps;
  }

  return summary;
}

export function applyEnrollmentCableUpdate(summaries = {}, payload) {
  const conversationId = Number(payload?.conversation_id);
  if (!conversationId) return summaries;

  const next = { ...summaries };
  if (!IN_PROGRESS_ENROLLMENT_STATUSES.includes(payload.status)) {
    delete next[conversationId];
    return next;
  }

  const summary = summaryFromCablePayload(payload);
  if (!summary) return summaries;

  next[conversationId] = summary;
  return next;
}
