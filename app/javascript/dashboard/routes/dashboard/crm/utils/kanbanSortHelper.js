import {
  getCreatedAt,
  getDealValue,
  getEnteredAt,
  getPosition,
} from './pipelinePositionsHelper';

export const KANBAN_SORT_OPTIONS = [
  'name',
  'name_desc',
  'position',
  'deal_value_desc',
  'deal_value_asc',
  'newest',
  'oldest',
  'recently_updated',
  'time_in_stage',
];

export const DEFAULT_KANBAN_SORT = 'name';

/** Unix seconds, ms, or ISO → epoch ms */
const toTimestamp = value => {
  if (value == null || value === '') return 0;
  if (typeof value === 'number') {
    return value < 1e12 ? value * 1000 : value;
  }
  const parsed = Date.parse(value);
  if (!Number.isNaN(parsed)) return parsed;
  const asNumber = Number(value);
  if (!Number.isNaN(asNumber)) {
    return asNumber < 1e12 ? asNumber * 1000 : asNumber;
  }
  return 0;
};

const cardCreatedAt = (contact, pipelineId) =>
  getCreatedAt(contact, pipelineId) || contact.created_at;

const cardUpdatedAt = (contact, pipelineId) =>
  contact.last_activity_at || cardCreatedAt(contact, pipelineId);

/**
 * Ordena contatos de uma coluna do kanban conforme o critério visual selecionado.
 * @param {Array} contacts
 * @param {string} sortBy
 * @param {number|string} pipelineId
 * @returns {Array}
 */
export function sortKanbanContacts(contacts, sortBy = DEFAULT_KANBAN_SORT, pipelineId) {
  if (!Array.isArray(contacts) || contacts.length === 0) {
    return [];
  }

  const list = [...contacts];

  const compareName = (a, b) =>
    (a.name || '').localeCompare(b.name || '', undefined, { sensitivity: 'base' });

  switch (sortBy) {
    case 'name_desc':
      return list.sort((a, b) => compareName(b, a));

    case 'position':
      return list.sort((a, b) => {
        const posA = getPosition(a, pipelineId);
        const posB = getPosition(b, pipelineId);

        if (posA != null && posB != null) return posA - posB;
        if (posA != null) return -1;
        if (posB != null) return 1;

        return toTimestamp(cardCreatedAt(a, pipelineId)) - toTimestamp(cardCreatedAt(b, pipelineId));
      });

    case 'deal_value_desc':
      return list.sort((a, b) => {
        const valueA = getDealValue(a, pipelineId) || 0;
        const valueB = getDealValue(b, pipelineId) || 0;
        if (valueB !== valueA) return valueB - valueA;
        return compareName(a, b);
      });

    case 'deal_value_asc':
      return list.sort((a, b) => {
        const valueA = getDealValue(a, pipelineId) || 0;
        const valueB = getDealValue(b, pipelineId) || 0;
        if (valueA !== valueB) return valueA - valueB;
        return compareName(a, b);
      });

    case 'newest':
      return list.sort(
        (a, b) =>
          toTimestamp(cardCreatedAt(b, pipelineId)) - toTimestamp(cardCreatedAt(a, pipelineId))
      );

    case 'oldest':
      return list.sort(
        (a, b) =>
          toTimestamp(cardCreatedAt(a, pipelineId)) - toTimestamp(cardCreatedAt(b, pipelineId))
      );

    case 'recently_updated':
      return list.sort(
        (a, b) =>
          toTimestamp(cardUpdatedAt(b, pipelineId)) - toTimestamp(cardUpdatedAt(a, pipelineId))
      );

    case 'time_in_stage':
      return list.sort((a, b) => {
        const enteredA = toTimestamp(getEnteredAt(a, pipelineId));
        const enteredB = toTimestamp(getEnteredAt(b, pipelineId));
        // Mais tempo na etapa = entered_at mais antigo primeiro
        if (enteredA !== enteredB) return enteredA - enteredB;
        return compareName(a, b);
      });

    case 'name':
    default:
      return list.sort(compareName);
  }
}

export function isValidKanbanSort(sortBy) {
  return KANBAN_SORT_OPTIONS.includes(sortBy);
}
