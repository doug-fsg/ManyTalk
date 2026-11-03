import {
  getConversationAssignee,
  getPipelineOwnershipMode,
  isLinkedOwnership,
  withPrimaryConversation,
} from '../pipelinePositionsHelper';

describe('pipeline ownership helpers', () => {
  it('defaults missing mode to linked', () => {
    expect(getPipelineOwnershipMode({})).toBe('linked');
    expect(getPipelineOwnershipMode(null)).toBe('linked');
  });

  it('reads split from the pipeline payload', () => {
    expect(getPipelineOwnershipMode({ ownership_mode: 'split' })).toBe('split');
    expect(isLinkedOwnership('split')).toBe(false);
    expect(isLinkedOwnership({ ownership_mode: 'linked' })).toBe(true);
  });

  it('reads conversation assignee from the pipeline position', () => {
    const contact = {
      pipeline_positions: [
        {
          pipeline_id: 19,
          conversation_assignee: { id: 8, name: 'Bruno' },
        },
      ],
    };
    expect(getConversationAssignee(contact, 19)).toEqual({ id: 8, name: 'Bruno' });
  });

  it('keeps existing metadata when selecting a conversation', () => {
    expect(withPrimaryConversation({ win_lost: { status: 'won' } }, 12)).toEqual({
      win_lost: { status: 'won' },
      primary_conversation_id: 12,
    });
  });
});
