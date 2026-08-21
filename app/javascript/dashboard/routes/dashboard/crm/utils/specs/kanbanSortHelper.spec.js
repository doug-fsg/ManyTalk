import { sortKanbanContacts, DEFAULT_KANBAN_SORT } from '../kanbanSortHelper';

const buildContact = (overrides = {}) => ({
  id: overrides.id || 1,
  name: overrides.name || 'Contact',
  created_at: overrides.created_at ?? 1609459200,
  last_activity_at: overrides.last_activity_at,
  pipeline_positions: [
    {
      pipeline_id: 10,
      stage_id: 'Stage',
      position: overrides.position ?? 0,
      deal_value: overrides.deal_value ?? 0,
      entered_at: overrides.entered_at || '2024-01-01T00:00:00Z',
      created_at: overrides.card_created_at || '2024-01-01T00:00:00Z',
    },
  ],
});

describe('sortKanbanContacts', () => {
  const pipelineId = 10;

  it('defaults to name ascending', () => {
    const contacts = [
      buildContact({ id: 1, name: 'Zoe' }),
      buildContact({ id: 2, name: 'Ana' }),
      buildContact({ id: 3, name: 'Mia' }),
    ];

    const sorted = sortKanbanContacts(contacts, DEFAULT_KANBAN_SORT, pipelineId);
    expect(sorted.map(c => c.name)).toEqual(['Ana', 'Mia', 'Zoe']);
  });

  it('sorts by deal value descending', () => {
    const contacts = [
      buildContact({ id: 1, name: 'A', deal_value: 10 }),
      buildContact({ id: 2, name: 'B', deal_value: 50 }),
      buildContact({ id: 3, name: 'C', deal_value: 30 }),
    ];

    const sorted = sortKanbanContacts(contacts, 'deal_value_desc', pipelineId);
    expect(sorted.map(c => c.id)).toEqual([2, 3, 1]);
  });

  it('sorts by manual position', () => {
    const contacts = [
      buildContact({ id: 1, name: 'A', position: 2 }),
      buildContact({ id: 2, name: 'B', position: 0 }),
      buildContact({ id: 3, name: 'C', position: 1 }),
    ];

    const sorted = sortKanbanContacts(contacts, 'position', pipelineId);
    expect(sorted.map(c => c.id)).toEqual([2, 3, 1]);
  });

  it('sorts newest by pipeline card created_at, not contact created_at', () => {
    const contacts = [
      buildContact({
        id: 1,
        name: 'Old contact, new card',
        created_at: 1609459200,
        card_created_at: '2026-08-20T12:00:00Z',
      }),
      buildContact({
        id: 2,
        name: 'New contact, old card',
        created_at: 1730000000,
        card_created_at: '2026-01-01T12:00:00Z',
      }),
    ];

    const sorted = sortKanbanContacts(contacts, 'newest', pipelineId);
    expect(sorted.map(c => c.id)).toEqual([1, 2]);
  });

  it('sorts by recently updated using last_activity_at', () => {
    const contacts = [
      buildContact({ id: 1, name: 'A', last_activity_at: 1700000000 }),
      buildContact({ id: 2, name: 'B', last_activity_at: 1730000000 }),
      buildContact({ id: 3, name: 'C', last_activity_at: 1710000000 }),
    ];

    const sorted = sortKanbanContacts(contacts, 'recently_updated', pipelineId);
    expect(sorted.map(c => c.id)).toEqual([2, 3, 1]);
  });
});
