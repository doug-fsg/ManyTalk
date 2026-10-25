import { DEFAULT_KANBAN_DATE_FIELD } from './kanbanFilterQueryHelper';
import { mergeKanbanFilters } from './kanbanFilterState';

export const KANBAN_FILTER_QUERY_KEYS = [
  'win_lost',
  'stage',
  'stale_days',
  'labels',
  'label_mode',
  'date_from',
  'date_to',
  'date_field',
  'deal_presence',
  'deal_min',
  'deal_max',
  'mine',
  'assignee_id',
  'assignee_ids',
];

function splitList(value, separator = ',') {
  if (!value) return [];
  return String(value)
    .split(separator)
    .map(item => item.trim())
    .filter(Boolean);
}

function resolveAssignee(id, { agents = [], currentUser, t } = {}) {
  if (id === 'none' || id === 'null') {
    return { id: null, name: t ? t('KANBAN.FILTERS.NO_ASSIGNEE') : '' };
  }
  const numericId = Number(id);
  if (Number.isNaN(numericId)) return null;
  if (currentUser?.id === numericId) {
    return {
      id: currentUser.id,
      name: currentUser.available_name || currentUser.name,
    };
  }
  const agent = agents.find(item => item.id === numericId);
  if (!agent) return { id: numericId, name: String(numericId) };
  return { id: agent.id, name: agent.available_name || agent.name };
}

export function serializeKanbanFiltersToQuery(filters = {}, { currentUserId } = {}) {
  const merged = mergeKanbanFilters(filters);
  const query = {};

  if (merged.winLost && merged.winLost !== 'open') query.win_lost = merged.winLost;
  if (merged.stages.length) query.stage = merged.stages.join('|');
  if (merged.staleDays) query.stale_days = String(merged.staleDays);
  if (merged.labels.length) query.labels = merged.labels.join(',');
  if (merged.labels.length > 1 && merged.labelMatchMode === 'all') {
    query.label_mode = 'all';
  }
  if (merged.dateFrom) query.date_from = merged.dateFrom;
  if (merged.dateTo) query.date_to = merged.dateTo;
  if (merged.dateFrom || merged.dateTo) {
    if (merged.dateField && merged.dateField !== DEFAULT_KANBAN_DATE_FIELD) {
      query.date_field = merged.dateField;
    }
  }
  if (merged.dealPresence && merged.dealPresence !== 'all') {
    query.deal_presence = merged.dealPresence;
  }
  if (merged.dealPresence !== 'without') {
    if (merged.dealValueMin !== null && merged.dealValueMin !== '') {
      query.deal_min = String(merged.dealValueMin);
    }
    if (merged.dealValueMax !== null && merged.dealValueMax !== '') {
      query.deal_max = String(merged.dealValueMax);
    }
  }

  const assigneeIds = (merged.assignees || []).map(assignee =>
    assignee?.id == null ? 'none' : String(assignee.id)
  );
  if (assigneeIds.length === 1) {
    if (currentUserId != null && assigneeIds[0] === String(currentUserId)) {
      query.mine = '1';
    } else {
      query.assignee_id = assigneeIds[0];
    }
  } else if (assigneeIds.length > 1) {
    query.assignee_ids = assigneeIds.join(',');
  }

  return query;
}

export function parseKanbanFiltersFromQuery(query = {}, context = {}) {
  const filters = mergeKanbanFilters();
  if (!query || typeof query !== 'object') return filters;

  if (query.win_lost) filters.winLost = String(query.win_lost);
  filters.stages = splitList(query.stage, '|');
  if (query.stale_days) {
    const days = Number(query.stale_days);
    if (days > 0) filters.staleDays = days;
  }
  filters.labels = splitList(query.labels).map(Number).filter(id => !Number.isNaN(id));
  if (query.label_mode === 'all') filters.labelMatchMode = 'all';
  filters.dateFrom = query.date_from || null;
  filters.dateTo = query.date_to || null;
  if (query.date_field) filters.dateField = String(query.date_field);
  if (query.deal_presence) filters.dealPresence = String(query.deal_presence);
  if (query.deal_min !== undefined && query.deal_min !== '') {
    filters.dealValueMin = Number(query.deal_min);
  }
  if (query.deal_max !== undefined && query.deal_max !== '') {
    filters.dealValueMax = Number(query.deal_max);
  }

  const assigneeTokens = splitList(query.assignee_ids);
  if (!assigneeTokens.length && query.assignee_id && query.assignee_id !== 'all') {
    assigneeTokens.push(String(query.assignee_id));
  }
  if (query.mine === '1' && context.currentUser?.id && !assigneeTokens.length) {
    assigneeTokens.push(String(context.currentUser.id));
  }
  filters.assignees = assigneeTokens
    .map(token => resolveAssignee(token, context))
    .filter(Boolean);

  return filters;
}

export function mergeRouteQueryWithKanbanFilters(existingQuery = {}, filterQuery = {}) {
  const next = { ...existingQuery };
  KANBAN_FILTER_QUERY_KEYS.forEach(key => {
    delete next[key];
  });
  Object.keys(filterQuery).forEach(key => {
    if (filterQuery[key] != null && filterQuery[key] !== '') {
      next[key] = filterQuery[key];
    }
  });
  return next;
}
