import { DEFAULT_KANBAN_DATE_FIELD } from './kanbanFilterQueryHelper';

export const DEFAULT_KANBAN_FILTERS = {
  labels: [],
  labelMatchMode: 'any',
  stages: [],
  dealValueMin: null,
  dealValueMax: null,
  dealPresence: 'all',
  dateFrom: null,
  dateTo: null,
  dateField: DEFAULT_KANBAN_DATE_FIELD,
  staleDays: null,
  assignees: [],
  winLost: 'open',
};

export function mergeKanbanFilters(filters = {}) {
  return {
    ...DEFAULT_KANBAN_FILTERS,
    ...filters,
    labels: Array.isArray(filters.labels) ? [...filters.labels] : [],
    stages: Array.isArray(filters.stages) ? [...filters.stages] : [],
    assignees: Array.isArray(filters.assignees) ? [...filters.assignees] : [],
    labelMatchMode: filters.labelMatchMode === 'all' ? 'all' : 'any',
    dateField: filters.dateField || DEFAULT_KANBAN_DATE_FIELD,
    dealPresence: filters.dealPresence || 'all',
    winLost: filters.winLost || 'open',
  };
}

export function formatLocalDateInput(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function startOfLocalWeek(date = new Date()) {
  const local = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = local.getDay();
  const diff = weekday === 0 ? -6 : 1 - weekday;
  local.setDate(local.getDate() + diff);
  return local;
}

export function isMineFilter(filters, currentUserId) {
  const assignees = filters?.assignees || [];
  return (
    currentUserId != null &&
    assignees.length === 1 &&
    assignees[0]?.id === currentUserId
  );
}

export function toggleMineFilter(filters, currentUser) {
  const merged = mergeKanbanFilters(filters);
  if (!currentUser?.id) return merged;
  if (isMineFilter(merged, currentUser.id)) {
    return { ...merged, assignees: [] };
  }
  return {
    ...merged,
    assignees: [
      {
        id: currentUser.id,
        name: currentUser.available_name || currentUser.name,
      },
    ],
  };
}

function assigneeKey(assignee) {
  return assignee?.id == null ? 'none' : String(assignee.id);
}

export function kanbanFiltersEqual(left, right) {
  const a = mergeKanbanFilters(left);
  const b = mergeKanbanFilters(right);
  const assigneeIds = list =>
    (list || [])
      .map(assigneeKey)
      .sort()
      .join(',');
  return (
    JSON.stringify([...(a.labels || [])].map(Number).sort()) ===
      JSON.stringify([...(b.labels || [])].map(Number).sort()) &&
    JSON.stringify([...(a.stages || [])].sort()) ===
      JSON.stringify([...(b.stages || [])].sort()) &&
    assigneeIds(a.assignees) === assigneeIds(b.assignees) &&
    a.labelMatchMode === b.labelMatchMode &&
    String(a.dealValueMin ?? '') === String(b.dealValueMin ?? '') &&
    String(a.dealValueMax ?? '') === String(b.dealValueMax ?? '') &&
    a.dealPresence === b.dealPresence &&
    (a.dateFrom || '') === (b.dateFrom || '') &&
    (a.dateTo || '') === (b.dateTo || '') &&
    a.dateField === b.dateField &&
    String(a.staleDays ?? '') === String(b.staleDays ?? '') &&
    a.winLost === b.winLost
  );
}

export function buildActiveFilterChips(
  filters = {},
  { labels = [], t = key => key } = {}
) {
  const merged = mergeKanbanFilters(filters);
  const chips = [];

  if (merged.winLost && merged.winLost !== 'open') {
    const statusKey = {
      won: 'KANBAN.FILTERS.WON',
      lost: 'KANBAN.FILTERS.LOST',
      all: 'KANBAN.FILTERS.ALL',
    }[merged.winLost];
    chips.push({
      id: 'winLost',
      type: 'winLost',
      label: `${t('KANBAN.FILTERS.STATUS')}: ${t(statusKey || 'KANBAN.FILTERS.ALL')}`,
    });
  }

  merged.stages.forEach(stage => {
    chips.push({
      id: `stage:${stage}`,
      type: 'stage',
      value: stage,
      label: `${t('KANBAN.FILTERS.STAGES')}: ${stage}`,
    });
  });

  merged.labels.forEach(labelId => {
    const label = labels.find(item => item.id === labelId || item.id === Number(labelId));
    chips.push({
      id: `label:${labelId}`,
      type: 'label',
      value: labelId,
      label: `${t('KANBAN.FILTERS.LABELS')}: ${label?.title || label?.name || labelId}`,
    });
  });

  if (merged.labels.length > 1 && merged.labelMatchMode === 'all') {
    chips.push({
      id: 'labelMatchMode',
      type: 'labelMatchMode',
      label: t('KANBAN.FILTERS.LABEL_MODE_ALL'),
    });
  }

  if (merged.staleDays) {
    chips.push({
      id: 'staleDays',
      type: 'staleDays',
      label: t('KANBAN.FILTERS.STALE_DAYS', { days: merged.staleDays }),
    });
  }

  if (merged.dateFrom || merged.dateTo) {
    const fieldKey = {
      entered_at: 'KANBAN.FILTERS.DATE_FIELD_STAGE',
      win_lost: 'KANBAN.FILTERS.DATE_FIELD_WIN_LOST',
    }[merged.dateField] || 'KANBAN.FILTERS.DATE_FIELD_CREATED';
    const range = [merged.dateFrom, merged.dateTo].filter(Boolean).join(' – ');
    chips.push({
      id: 'dateRange',
      type: 'dateRange',
      label: `${t(fieldKey)}: ${range}`,
    });
  }

  if (merged.dealPresence && merged.dealPresence !== 'all') {
    chips.push({
      id: 'dealPresence',
      type: 'dealPresence',
      label: t(
        merged.dealPresence === 'without'
          ? 'KANBAN.FILTERS.DEAL_WITHOUT_VALUE'
          : 'KANBAN.FILTERS.DEAL_WITH_VALUE'
      ),
    });
  }

  if (merged.dealPresence !== 'without') {
    if (merged.dealValueMin !== null && merged.dealValueMin !== '') {
      chips.push({
        id: 'dealValueMin',
        type: 'dealValueMin',
        label: `${t('KANBAN.FILTERS.MIN_VALUE')}: ${merged.dealValueMin}`,
      });
    }
    if (merged.dealValueMax !== null && merged.dealValueMax !== '') {
      chips.push({
        id: 'dealValueMax',
        type: 'dealValueMax',
        label: `${t('KANBAN.FILTERS.MAX_VALUE')}: ${merged.dealValueMax}`,
      });
    }
  }

  merged.assignees.forEach(assignee => {
    const name =
      assignee?.id == null
        ? t('KANBAN.FILTERS.NO_ASSIGNEE')
        : assignee.name || assignee.id;
    chips.push({
      id: `assignee:${assigneeKey(assignee)}`,
      type: 'assignee',
      value: assignee?.id ?? null,
      label: `${t('KANBAN.FILTERS.ASSIGNEE')}: ${name}`,
    });
  });

  return chips;
}

export function removeKanbanFilterChip(filters, chip) {
  const next = mergeKanbanFilters(filters);
  switch (chip?.type) {
    case 'winLost':
      next.winLost = 'open';
      break;
    case 'stage':
      next.stages = next.stages.filter(stage => stage !== chip.value);
      break;
    case 'label':
      next.labels = next.labels.filter(id => id !== chip.value && id !== Number(chip.value));
      break;
    case 'labelMatchMode':
      next.labelMatchMode = 'any';
      break;
    case 'staleDays':
      next.staleDays = null;
      break;
    case 'dateRange':
      next.dateFrom = null;
      next.dateTo = null;
      next.dateField = DEFAULT_KANBAN_DATE_FIELD;
      break;
    case 'dealPresence':
      next.dealPresence = 'all';
      break;
    case 'dealValueMin':
      next.dealValueMin = null;
      break;
    case 'dealValueMax':
      next.dealValueMax = null;
      break;
    case 'assignee':
      next.assignees = next.assignees.filter(assignee => {
        const id = assignee?.id ?? null;
        return id !== chip.value;
      });
      break;
    default:
      break;
  }
  return next;
}
