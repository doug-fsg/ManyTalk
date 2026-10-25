/**
 * @vitest-environment node
 */
import {
  buildKanbanFilterPayloadItems,
  contactMatchesKanbanFilters,
} from '../kanbanFilterQueryHelper';

describe('kanbanFilterQueryHelper', () => {
  it('builds date range filters with normalized inverted YYYY-MM-DD bounds', () => {
    const items = buildKanbanFilterPayloadItems({
      dateFrom: '2026-10-10',
      dateTo: '2026-10-01',
    });

    expect(items).toEqual([
      {
        attribute_key: '_pipeline_created_at',
        filter_operator: 'is_greater_than',
        values: ['2026-10-01'],
        query_operator: 'AND',
      },
      {
        attribute_key: '_pipeline_created_at',
        filter_operator: 'is_less_than',
        values: ['2026-10-10'],
        query_operator: 'AND',
      },
    ]);
  });

  it('maps date field, stages, stale days and deal presence', () => {
    const items = buildKanbanFilterPayloadItems({
      dateFrom: '2026-10-01',
      dateTo: '2026-10-10',
      dateField: 'entered_at',
      stages: ['Proposta'],
      staleDays: 7,
      dealPresence: 'without',
      dealValueMin: 10,
    });

    expect(items).toEqual([
      {
        attribute_key: '_pipeline_entered_at',
        filter_operator: 'is_greater_than',
        values: ['2026-10-01'],
        query_operator: 'AND',
      },
      {
        attribute_key: '_pipeline_entered_at',
        filter_operator: 'is_less_than',
        values: ['2026-10-10'],
        query_operator: 'AND',
      },
      {
        attribute_key: '_pipeline_stage_id',
        filter_operator: 'equal_to',
        values: ['Proposta'],
        query_operator: 'AND',
      },
      {
        attribute_key: '_pipeline_stale_days',
        filter_operator: 'is_greater_than',
        values: [7],
        query_operator: 'AND',
      },
      {
        attribute_key: '_pipeline_deal_presence',
        filter_operator: 'equal_to',
        values: ['without'],
        query_operator: 'AND',
      },
    ]);
  });

  it('preserves deal value 0 via nullish checks', () => {
    const items = buildKanbanFilterPayloadItems({
      dealValueMin: 0,
      dealValueMax: 0,
    });

    expect(items).toEqual([
      {
        attribute_key: '_pipeline_deal_value',
        filter_operator: 'is_greater_than',
        values: [0],
        query_operator: 'AND',
      },
      {
        attribute_key: '_pipeline_deal_value',
        filter_operator: 'is_less_than',
        values: [0],
        query_operator: 'AND',
      },
    ]);
  });

  it('maps label ids to titles and skips winLost all', () => {
    const items = buildKanbanFilterPayloadItems(
      {
        labels: [2, 9],
        winLost: 'all',
      },
      {
        labels: [
          { id: 2, title: 'vip' },
          { id: 9, title: 'hot' },
        ],
      }
    );

    expect(items).toEqual([
      {
        attribute_key: '_labels',
        filter_operator: 'equal_to',
        values: ['vip', 'hot'],
        query_operator: 'AND',
      },
    ]);
  });

  it('emits one labels condition per title when match mode is all', () => {
    const items = buildKanbanFilterPayloadItems(
      {
        labels: [2, 9],
        labelMatchMode: 'all',
      },
      {
        labels: [
          { id: 2, title: 'vip' },
          { id: 9, title: 'hot' },
        ],
      }
    );

    expect(items.filter(item => item.attribute_key === '_labels')).toEqual([
      {
        attribute_key: '_labels',
        filter_operator: 'equal_to',
        values: ['vip'],
        query_operator: 'AND',
      },
      {
        attribute_key: '_labels',
        filter_operator: 'equal_to',
        values: ['hot'],
        query_operator: 'AND',
      },
    ]);
  });

  it('includes open winLost and assignee ids', () => {
    const items = buildKanbanFilterPayloadItems({
      winLost: 'open',
      assignees: [{ id: 5, name: 'Alice' }, { id: null, name: 'Unassigned' }],
    });

    expect(items).toContainEqual({
      attribute_key: '_pipeline_win_lost',
      filter_operator: 'equal_to',
      values: ['open'],
      query_operator: 'AND',
    });
    expect(items).toContainEqual({
      attribute_key: '_pipeline_assignee_id',
      filter_operator: 'equal_to',
      values: [5, null],
      query_operator: 'AND',
    });
  });

  it('matches contact by shared filter rules', () => {
    const contact = {
      name: 'Ana',
      email: 'ana@x.com',
      phone_number: '',
      labels: [{ id: 2 }],
      pipeline_positions: [
        {
          pipeline_id: 10,
          created_at: '2026-10-06T15:00:00.000Z',
          deal_value: 100,
          assignee: { id: 5 },
          metadata: {},
        },
      ],
    };

    expect(
      contactMatchesKanbanFilters(contact, {
        filters: {
          dateFrom: '2026-10-06',
          dateTo: '2026-10-06',
          dealValueMin: 50,
          labels: [2],
          assignees: [{ id: 5 }],
          winLost: 'open',
        },
        winLostFilter: 'open',
        pipelineId: 10,
      })
    ).toBe(true);

    expect(
      contactMatchesKanbanFilters(contact, {
        searchQuery: 'bruno',
        filters: {},
        pipelineId: 10,
      })
    ).toBe(false);
  });

  it('matches stage, stale days and deal presence on the client', () => {
    const tenDaysAgo = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
    const contact = {
      name: 'Ana',
      pipeline_positions: [
        {
          pipeline_id: 10,
          stage_id: 'Proposta',
          entered_at: tenDaysAgo,
          created_at: tenDaysAgo,
          deal_value: null,
        },
      ],
    };

    expect(
      contactMatchesKanbanFilters(contact, {
        filters: { stages: ['Proposta'], staleDays: 7, dealPresence: 'without' },
        pipelineId: 10,
      })
    ).toBe(true);

    expect(
      contactMatchesKanbanFilters(contact, {
        filters: { stages: ['Negociação'] },
        pipelineId: 10,
      })
    ).toBe(false);

    expect(
      contactMatchesKanbanFilters(contact, {
        filters: { dealPresence: 'with' },
        pipelineId: 10,
      })
    ).toBe(false);
  });

  it('matches all selected labels when labelMatchMode is all', () => {
    const contact = {
      name: 'Ana',
      labels: [{ id: 2 }, { id: 9 }],
      pipeline_positions: [{ pipeline_id: 10 }],
    };

    expect(
      contactMatchesKanbanFilters(contact, {
        filters: { labels: [2, 9], labelMatchMode: 'all' },
        pipelineId: 10,
      })
    ).toBe(true);

    expect(
      contactMatchesKanbanFilters(contact, {
        filters: { labels: [2, 3], labelMatchMode: 'all' },
        pipelineId: 10,
      })
    ).toBe(false);
  });
});
