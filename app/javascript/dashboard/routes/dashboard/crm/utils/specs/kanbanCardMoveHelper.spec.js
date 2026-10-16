import {
  enteredAtForMove,
  buildColumnReorderPositions,
  applyLocalColumnPositions,
} from '../kanbanCardMoveHelper';
import { sortKanbanContacts } from '../kanbanSortHelper';

const pipelineId = 10;

const contact = (id, position, stage = 'A', entered_at = '2024-01-01T00:00:00Z') => ({
  id,
  name: `C${id}`,
  pipeline_positions: [
    {
      pipeline_id: pipelineId,
      stage_id: stage,
      position,
      entered_at,
      created_at: '2024-01-01T00:00:00Z',
      deal_value: 0,
    },
  ],
});

describe('enteredAtForMove', () => {
  it('does not reset entered_at on same-stage reorder', () => {
    expect(enteredAtForMove('A', 'A', () => '2026-01-01T00:00:00Z')).toBeNull();
  });

  it('sets entered_at when stage changes', () => {
    expect(enteredAtForMove('A', 'B', () => '2026-01-01T00:00:00Z')).toBe(
      '2026-01-01T00:00:00Z'
    );
  });
});

describe('buildColumnReorderPositions', () => {
  it('renumbers entire column with unique positions after same-stage reorder', () => {
    // Visual order after drag: C, A, B
    const targetItems = [contact(3, 2), contact(1, 0), contact(2, 1)];
    const positions = buildColumnReorderPositions({
      sourceStage: 'A',
      targetStage: 'A',
      sourceItems: targetItems,
      targetItems,
      movedContactId: 3,
      enteredAt: null,
    });

    expect(positions.map(p => p.position)).toEqual([0, 1, 2]);
    expect(positions.map(p => p.contact_id)).toEqual([3, 1, 2]);
    expect(positions.every(p => !p.entered_at)).toBe(true);

    const after = targetItems.map((c, i) => ({
      ...c,
      pipeline_positions: [{ ...c.pipeline_positions[0], position: i }],
    }));
    expect(sortKanbanContacts(after, 'position', pipelineId).map(c => c.id)).toEqual([
      3, 1, 2,
    ]);
  });

  it('includes entered_at only for moved card on stage change', () => {
    const sourceItems = [contact(1, 0, 'A')];
    const targetItems = [contact(2, 0, 'B'), contact(3, 1, 'A')];
    const positions = buildColumnReorderPositions({
      sourceStage: 'A',
      targetStage: 'B',
      sourceItems,
      targetItems,
      movedContactId: 3,
      enteredAt: '2026-06-01T00:00:00Z',
    });

    const moved = positions.find(p => p.contact_id === 3);
    const other = positions.find(p => p.contact_id === 2);
    expect(moved.entered_at).toBe('2026-06-01T00:00:00Z');
    expect(moved.stage_id).toBe('B');
    expect(other.entered_at).toBeUndefined();
  });
});

describe('applyLocalColumnPositions', () => {
  it('writes sequential positions onto pipeline_positions', () => {
    const items = [contact(3, 9), contact(1, 9), contact(2, 9)];
    applyLocalColumnPositions(items, pipelineId, 'A');
    expect(items.map(c => c.pipeline_positions[0].position)).toEqual([0, 1, 2]);
    expect(items.every(c => c.pipeline_positions[0].stage_id === 'A')).toBe(true);
  });
});
