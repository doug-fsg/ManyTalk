import { matchesKanbanDateRange, normalizeKanbanDateRange } from './kanbanDateFilterHelper';
import {
  getCreatedAt,
  getDealValue,
  getEnteredAt,
  getWinLostStatus,
} from './pipelinePositionsHelper';

/**
 * Payload + match dos filtros do Kanban (chaves _pipeline_* no Contacts::FilterService).
 * Datas no wire: YYYY-MM-DD; o backend expande o dia em America/Sao_Paulo.
 */

export const KANBAN_DATE_FIELD_KEYS = {
  created_at: '_pipeline_created_at',
  entered_at: '_pipeline_entered_at',
  win_lost: '_pipeline_win_lost_at',
};

export const DEFAULT_KANBAN_DATE_FIELD = 'created_at';

export function pipelineStageNames(attributeValues = []) {
  if (!Array.isArray(attributeValues)) return [];
  return attributeValues
    .map(value => {
      if (typeof value === 'object' && value !== null) {
        return value.name || value.value || String(value);
      }
      return String(value);
    })
    .filter(Boolean);
}

function pushDateRangeItems(items, attributeKey, dateFrom, dateTo) {
  if (dateFrom) {
    items.push({
      attribute_key: attributeKey,
      filter_operator: 'is_greater_than',
      values: [dateFrom],
      query_operator: 'AND',
    });
  }

  if (dateTo) {
    items.push({
      attribute_key: attributeKey,
      filter_operator: 'is_less_than',
      values: [dateTo],
      query_operator: 'AND',
    });
  }
}

function contactDateValue(contact, pipelineId, dateField) {
  if (dateField === 'entered_at') {
    return getEnteredAt(contact, pipelineId);
  }
  if (dateField === 'win_lost') {
    return getWinLostStatus(contact, pipelineId)?.date || null;
  }
  return getCreatedAt(contact, pipelineId);
}

function daysInCurrentStage(contact, pipelineId) {
  const enteredAt = getEnteredAt(contact, pipelineId);
  if (!enteredAt) return null;
  const timestamp = new Date(enteredAt).getTime();
  if (Number.isNaN(timestamp)) return null;
  return (Date.now() - timestamp) / (1000 * 60 * 60 * 24);
}

export function buildKanbanFilterPayloadItems(filters = {}, { labels = [] } = {}) {
  const items = [];
  const {
    dealValueMin,
    dealValueMax,
    dealPresence,
    assignees,
    winLost,
    labels: selectedLabelIds,
    stages,
    staleDays,
  } = filters;

  const { dateFrom, dateTo } = normalizeKanbanDateRange(
    filters.dateFrom,
    filters.dateTo
  );
  const dateField = filters.dateField || DEFAULT_KANBAN_DATE_FIELD;
  const dateAttributeKey =
    KANBAN_DATE_FIELD_KEYS[dateField] || KANBAN_DATE_FIELD_KEYS.created_at;

  pushDateRangeItems(items, dateAttributeKey, dateFrom, dateTo);

  if (Array.isArray(stages) && stages.length > 0) {
    items.push({
      attribute_key: '_pipeline_stage_id',
      filter_operator: 'equal_to',
      values: stages,
      query_operator: 'AND',
    });
  }

  const parsedStaleDays = Number(staleDays);
  if (staleDays !== null && staleDays !== undefined && staleDays !== '' && parsedStaleDays > 0) {
    items.push({
      attribute_key: '_pipeline_stale_days',
      filter_operator: 'is_greater_than',
      values: [parsedStaleDays],
      query_operator: 'AND',
    });
  }

  if (dealPresence === 'with' || dealPresence === 'without') {
    items.push({
      attribute_key: '_pipeline_deal_presence',
      filter_operator: 'equal_to',
      values: [dealPresence],
      query_operator: 'AND',
    });
  }

  if (dealPresence !== 'without') {
    if (dealValueMin !== null && dealValueMin !== undefined && dealValueMin !== '') {
      items.push({
        attribute_key: '_pipeline_deal_value',
        filter_operator: 'is_greater_than',
        values: [dealValueMin],
        query_operator: 'AND',
      });
    }

    if (dealValueMax !== null && dealValueMax !== undefined && dealValueMax !== '') {
      items.push({
        attribute_key: '_pipeline_deal_value',
        filter_operator: 'is_less_than',
        values: [dealValueMax],
        query_operator: 'AND',
      });
    }
  }

  if (Array.isArray(assignees) && assignees.length > 0) {
    items.push({
      attribute_key: '_pipeline_assignee_id',
      filter_operator: 'equal_to',
      values: assignees.map(a => (a && typeof a === 'object' ? a.id : a)),
      query_operator: 'AND',
    });
  }

  if (winLost && winLost !== 'all') {
    items.push({
      attribute_key: '_pipeline_win_lost',
      filter_operator: 'equal_to',
      values: [winLost],
      query_operator: 'AND',
    });
  }

  if (Array.isArray(selectedLabelIds) && selectedLabelIds.length > 0) {
    const titles = selectedLabelIds
      .map(id => {
        const label = labels.find(l => l.id === id || l.id === Number(id));
        return label?.title || label?.name;
      })
      .filter(Boolean);

    if (titles.length) {
      if (filters.labelMatchMode === 'all' && titles.length > 1) {
        titles.forEach(title => {
          items.push({
            attribute_key: '_labels',
            filter_operator: 'equal_to',
            values: [title],
            query_operator: 'AND',
          });
        });
      } else {
        items.push({
          attribute_key: '_labels',
          filter_operator: 'equal_to',
          values: titles,
          query_operator: 'AND',
        });
      }
    }
  }

  return items;
}

/**
 * Match client-side (colunas / lista) — mesma regra dos filtros do payload.
 */
export function contactMatchesKanbanFilters(
  contact,
  { searchQuery = '', winLostFilter = 'all', filters = {}, pipelineId = null } = {}
) {
  const q = (searchQuery || '').toLowerCase().trim();
  if (q) {
    const name = (contact.name || '').toLowerCase();
    const email = (contact.email || '').toLowerCase();
    const phone = (contact.phone_number || '').toLowerCase();
    if (!name.includes(q) && !email.includes(q) && !phone.includes(q)) {
      return false;
    }
  }

  if (winLostFilter && winLostFilter !== 'all' && pipelineId != null) {
    const status = getWinLostStatus(contact, pipelineId)?.status;
    if (winLostFilter === 'won' && status !== 'won') return false;
    if (winLostFilter === 'lost' && status !== 'lost') return false;
    if (winLostFilter === 'open' && status) return false;
  }

  if (filters.labels?.length) {
    const contactLabelIds = (contact.labels || [])
      .map(label => (label && typeof label === 'object' ? label.id : label))
      .filter(id => id != null);
    const hasLabel = id => contactLabelIds.includes(id) || contactLabelIds.includes(Number(id));
    const matchesLabels =
      filters.labelMatchMode === 'all'
        ? filters.labels.every(hasLabel)
        : filters.labels.some(hasLabel);
    if (!matchesLabels) return false;
  }

  if (pipelineId != null) {
    const position = contact.pipeline_positions?.find(
      p => p.pipeline_id === pipelineId || p.pipeline_id === parseInt(pipelineId, 10)
    );

    if (filters.stages?.length) {
      if (!filters.stages.includes(position?.stage_id)) return false;
    }

    const parsedStaleDays = Number(filters.staleDays);
    if (
      filters.staleDays !== null &&
      filters.staleDays !== undefined &&
      filters.staleDays !== '' &&
      parsedStaleDays > 0
    ) {
      const days = daysInCurrentStage(contact, pipelineId);
      if (days == null || days < parsedStaleDays) return false;
    }

    const dealValue = getDealValue(contact, pipelineId);
    if (filters.dealPresence === 'with' && !(dealValue > 0)) return false;
    if (filters.dealPresence === 'without' && dealValue > 0) return false;

    if (filters.dealPresence !== 'without') {
      const numericDealValue = dealValue || 0;
      if (filters.dealValueMin !== null && filters.dealValueMin !== undefined && filters.dealValueMin !== '') {
        if (numericDealValue < parseFloat(filters.dealValueMin)) return false;
      }
      if (filters.dealValueMax !== null && filters.dealValueMax !== undefined && filters.dealValueMax !== '') {
        if (numericDealValue > parseFloat(filters.dealValueMax)) return false;
      }
    }

    if (filters.dateFrom || filters.dateTo) {
      const dateField = filters.dateField || DEFAULT_KANBAN_DATE_FIELD;
      if (
        !matchesKanbanDateRange(
          contactDateValue(contact, pipelineId, dateField),
          filters.dateFrom,
          filters.dateTo
        )
      ) {
        return false;
      }
    }

    if (filters.assignees?.length) {
      const assigneeId = position?.assignee?.id || null;
      const selectedIds = filters.assignees.map(a => a.id);
      if (!selectedIds.includes(assigneeId) && !(selectedIds.includes(null) && assigneeId === null)) {
        return false;
      }
    }
  } else if (filters.dateFrom || filters.dateTo || filters.stages?.length || filters.staleDays) {
    return false;
  }

  return true;
}
