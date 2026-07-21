import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

export const KANBAN_CARD_MODAL_TAB_KEY = 'crm_kanban_card_modal_tab';

export function buildKanbanDeepLink(
  accountId,
  { contactId, pipelineId, tab, assigneeId } = {}
) {
  const query = {};
  if (contactId != null) query.contactId = String(contactId);
  if (pipelineId != null) query.pipelineId = String(pipelineId);
  if (tab) query.tab = tab;
  if (assigneeId != null && assigneeId !== 'all') {
    query.assignee_id = String(assigneeId);
  }
  return {
    name: 'kanban_view',
    params: { accountId: String(accountId) },
    query,
  };
}

export function buildActivitiesDeepLink(
  accountId,
  { assigneeId, status, pipelineId } = {}
) {
  const query = {};
  if (assigneeId != null && assigneeId !== 'all') {
    query.assignee_id = String(assigneeId);
  }
  if (status) query.status = status;
  if (pipelineId != null) query.pipeline_id = String(pipelineId);
  return {
    name: 'activities_view',
    params: { accountId: String(accountId) },
    query,
  };
}

export function readLastPipelineId() {
  try {
    const id = localStorage.getItem(
      LOCAL_STORAGE_KEYS.KANBAN_SELECTED_PIPELINE
    );
    return id ? Number(id) : null;
  } catch (error) {
    return null;
  }
}

export function resolveKanbanAssigneeForActivitiesSync(
  kanbanFilters,
  currentUserId
) {
  const assignees = kanbanFilters?.assignees;
  if (assignees?.length === 1) return assignees[0].id;
  if (currentUserId) return currentUserId;
  return 'all';
}

export function parseOpenCardModalPayload(payload) {
  if (payload && typeof payload === 'object' && payload.contact) {
    return {
      contact: payload.contact,
      initialTab: payload.initialTab || null,
      highlightActivityId: payload.highlightActivityId || null,
    };
  }
  return { contact: payload, initialTab: null, highlightActivityId: null };
}

export function getActivityCountForContact(getter, contactId) {
  if (!getter || contactId == null) return 0;
  return (
    getter(contactId) ||
    getter(String(contactId)) ||
    getter(Number(contactId)) ||
    0
  );
}

export function resolveCardModalTab({ initialTab, hasOverdueActivities } = {}) {
  if (
    initialTab === 'activities' ||
    initialTab === 'notes' ||
    initialTab === 'timeline'
  ) {
    return initialTab;
  }
  if (hasOverdueActivities) return 'activities';
  return 'timeline';
}

export function resolveContactProfileTabIndex({
  initialTab,
  hasOverdueActivities,
} = {}) {
  const tabIndexByKey = {
    timeline: 0,
    deal: 1,
    notes: 2,
    activities: 3,
  };

  if (initialTab && tabIndexByKey[initialTab] != null) {
    return tabIndexByKey[initialTab];
  }
  if (hasOverdueActivities) return 3;
  return 0;
}

export function readStoredCardModalTab() {
  try {
    return localStorage.getItem(KANBAN_CARD_MODAL_TAB_KEY);
  } catch (error) {
    return null;
  }
}

export function storeCardModalTab(tab) {
  if (tab !== 'notes') return;
  try {
    localStorage.setItem(KANBAN_CARD_MODAL_TAB_KEY, tab);
  } catch (error) {
    // ignore storage errors
  }
}
