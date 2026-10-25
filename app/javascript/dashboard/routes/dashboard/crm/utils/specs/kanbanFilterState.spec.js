/**
 * @vitest-environment node
 */
import {
  buildActiveFilterChips,
  isMineFilter,
  kanbanFiltersEqual,
  mergeKanbanFilters,
  removeKanbanFilterChip,
  startOfLocalWeek,
  toggleMineFilter,
} from '../kanbanFilterState';
import {
  mergeRouteQueryWithKanbanFilters,
  parseKanbanFiltersFromQuery,
  serializeKanbanFiltersToQuery,
} from '../kanbanFilterQuerySync';
const t = key => key;

describe('kanbanFilterState', () => {
  it('toggles mine filter for the current user', () => {
    const user = { id: 7, name: 'Ana' };
    const withMine = toggleMineFilter(mergeKanbanFilters(), user);
    expect(isMineFilter(withMine, 7)).toBe(true);
    expect(isMineFilter(toggleMineFilter(withMine, user), 7)).toBe(false);
  });

  it('builds removable chips and clears a stage chip', () => {
    const filters = mergeKanbanFilters({
      stages: ['Proposta'],
      winLost: 'won',
    });
    const chips = buildActiveFilterChips(filters, { t });
    expect(chips.map(chip => chip.type)).toEqual(['winLost', 'stage']);
    const next = removeKanbanFilterChip(filters, chips[1]);
    expect(next.stages).toEqual([]);
    expect(next.winLost).toBe('won');
  });

  it('starts the local week on Monday', () => {
    const wednesday = new Date(2026, 9, 21);
    expect(startOfLocalWeek(wednesday).getDay()).toBe(1);
    expect(startOfLocalWeek(wednesday).getDate()).toBe(19);
  });
});

describe('kanbanFilterQuerySync', () => {
  it('round-trips high-impact filters in the route query', () => {
    const filters = mergeKanbanFilters({
      stages: ['Proposta'],
      staleDays: 7,
      winLost: 'won',
      labels: [2],
      dateField: 'win_lost',
      dateFrom: '2026-10-19',
      dateTo: '2026-10-24',
      assignees: [{ id: 7, name: 'Ana' }],
    });
    const query = serializeKanbanFiltersToQuery(filters, { currentUserId: 7 });
    expect(query.mine).toBe('1');
    expect(query.stage).toBe('Proposta');
    expect(query.win_lost).toBe('won');

    const parsed = parseKanbanFiltersFromQuery(query, {
      currentUser: { id: 7, name: 'Ana' },
      t,
    });
    expect(kanbanFiltersEqual(filters, parsed)).toBe(true);
  });

  it('keeps contactId when merging filter query', () => {
    const next = mergeRouteQueryWithKanbanFilters(
      { contactId: '12', win_lost: 'won' },
      { stale_days: '7' }
    );
    expect(next.contactId).toBe('12');
    expect(next.win_lost).toBeUndefined();
    expect(next.stale_days).toBe('7');
  });
});

