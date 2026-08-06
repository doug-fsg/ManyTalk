import { sortKanbanContacts, DEFAULT_KANBAN_SORT } from '../kanbanSortHelper';

const buildContact = (overrides = {}) => ({
  id: overrides.id || 1,
  name: overrides.name || 'Contact',
  created_at: overrides.created_at || '2024-01-01T00:00:00Z',
  pipeline_positions: [
    {
      pipeline_id: 10,
      stage_id: 'Stage',
      position: overrides.position ?? 0,
      deal_value: overrides.deal_value ?? 0,
      entered_at: overrides.entered_at || '2024-01-01T00:00:00Z',
      created_at: overrides.created_at || '2024-01-01T00:00:00Z',
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
});
