import { matchesKanbanDateRange, normalizeKanbanDateRange } from './kanbanDateFilterHelper';
import {
  getCreatedAt,
  getDealValue,
  getWinLostStatus,
} from './pipelinePositionsHelper';

/**
 * Payload + match dos filtros do Kanban (chaves _pipeline_* no Contacts::FilterService).
 * Datas no wire: YYYY-MM-DD; o backend expande o dia em America/Sao_Paulo.
 */

export function buildKanbanFilterPayloadItems(filters = {}, { labels = [] } = {}) {
  const items = [];
  const {
    dealValueMin,
    dealValueMax,
    assignees,
    winLost,
    labels: selectedLabelIds,
  } = filters;

  const { dateFrom, dateTo } = normalizeKanbanDateRange(
    filters.dateFrom,
    filters.dateTo
  );

  if (dateFrom) {
    items.push({
      attribute_key: '_pipeline_created_at',
      filter_operator: 'is_greater_than',
      values: [dateFrom],
      query_operator: 'AND',
    });
  }

  if (dateTo) {
    items.push({
      attribute_key: '_pipeline_created_at',
      filter_operator: 'is_less_than',
      values: [dateTo],
      query_operator: 'AND',
    });
  }

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
      items.push({
        attribute_key: 'labels',
        filter_operator: 'equal_to',
        values: titles,
        query_operator: 'AND',
      });
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
    const contactLabelIds = (contact.labels || []).map(l => l.id);
    if (!filters.labels.some(id => contactLabelIds.includes(id))) return false;
  }

  if (pipelineId != null) {
    const dealValue = getDealValue(contact, pipelineId) || 0;
    if (filters.dealValueMin !== null && filters.dealValueMin !== undefined && filters.dealValueMin !== '') {
      if (dealValue < parseFloat(filters.dealValueMin)) return false;
    }
    if (filters.dealValueMax !== null && filters.dealValueMax !== undefined && filters.dealValueMax !== '') {
      if (dealValue > parseFloat(filters.dealValueMax)) return false;
    }

    if (filters.dateFrom || filters.dateTo) {
      if (
        !matchesKanbanDateRange(
          getCreatedAt(contact, pipelineId),
          filters.dateFrom,
          filters.dateTo
        )
      ) {
        return false;
      }
    }

    if (filters.assignees?.length) {
      const position = contact.pipeline_positions?.find(
        p => p.pipeline_id === pipelineId || p.pipeline_id === parseInt(pipelineId, 10)
      );
      const assigneeId = position?.assignee?.id || null;
      const selectedIds = filters.assignees.map(a => a.id);
      if (!selectedIds.includes(assigneeId) && !(selectedIds.includes(null) && assigneeId === null)) {
        return false;
      }
    }
  } else if (filters.dateFrom || filters.dateTo) {
    return false;
  }

  return true;
}
