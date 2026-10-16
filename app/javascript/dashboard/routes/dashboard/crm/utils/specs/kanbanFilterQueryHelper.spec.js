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
        attribute_key: 'labels',
        filter_operator: 'equal_to',
        values: ['vip', 'hot'],
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
});
