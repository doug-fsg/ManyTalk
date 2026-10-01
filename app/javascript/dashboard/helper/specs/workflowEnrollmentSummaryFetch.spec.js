import { describe, expect, it } from 'vitest';
import {
  applyEnrollmentCableUpdate,
  shouldFetchEnrollmentSummaries,
  summaryFromCablePayload,
  visibleConversationIdsKey,
} from '../workflowEnrollmentSummaryFetch';

describe('workflowEnrollmentSummaryFetch', () => {
  describe('visibleConversationIdsKey', () => {
    it('uses a stable set of the visible ids, independent of sort order', () => {
      const conversations = [{ id: 3 }, { id: 1 }, { id: 2 }];
      expect(visibleConversationIdsKey(conversations)).toBe('1,2,3');
      expect(visibleConversationIdsKey([{ id: 2 }, { id: 3 }, { id: 1 }])).toBe(
        '1,2,3'
      );
    });

    it('stays stable when conversation objects mutate but ids do not', () => {
      const conversations = [
        { id: 101, unread_count: 0, last_activity_at: 1000 },
        { id: 102, unread_count: 0, last_activity_at: 900 },
      ];
      const before = visibleConversationIdsKey(conversations);
      conversations[0].unread_count = 7;
      conversations[0].last_activity_at = 2000;
      expect(visibleConversationIdsKey(conversations)).toBe(before);
    });
  });

  describe('shouldFetchEnrollmentSummaries', () => {
    it('is false when visible ids are unchanged after last_activity mutation', () => {
      const list = [{ id: 101, last_activity_at: 1 }, { id: 102, last_activity_at: 2 }];
      const prevKey = visibleConversationIdsKey(list);
      list[0].last_activity_at = 99;
      expect(
        shouldFetchEnrollmentSummaries(prevKey, visibleConversationIdsKey(list))
      ).toBe(false);
    });

    it('is true when a conversation enters or leaves the visible set', () => {
      expect(shouldFetchEnrollmentSummaries('101,102', '101,102,103')).toBe(true);
      expect(shouldFetchEnrollmentSummaries('101,102', '102')).toBe(true);
    });
  });

  describe('summaryFromCablePayload', () => {
    it('maps cable fields to the list badge shape', () => {
      expect(
        summaryFromCablePayload({
          conversation_id: 42,
          enrollment_id: 9,
          workflow_id: 3,
          workflow_name: 'Boas-vindas',
          status: 'waiting',
          current_node_label: 'Espera · 6 hora(s)',
          current_node_type: 'wait',
          step_index: 2,
          total_steps: 4,
        })
      ).toEqual({
        enrollment_id: 9,
        workflow_id: 3,
        workflow_name: 'Boas-vindas',
        status: 'waiting',
        current_node_label: 'Espera · 6 hora(s)',
        current_node_type: 'wait',
        step_index: 2,
        total_steps: 4,
      });
    });

    it('returns null without conversation_id', () => {
      expect(summaryFromCablePayload({ enrollment_id: 1 })).toBeNull();
    });
  });

  describe('applyEnrollmentCableUpdate', () => {
    const existing = {
      42: { enrollment_id: 9, status: 'active', workflow_name: 'Old' },
    };

    it('patches a single conversation without refetching the list', () => {
      const next = applyEnrollmentCableUpdate(existing, {
        conversation_id: 42,
        enrollment_id: 9,
        workflow_name: 'Boas-vindas',
        status: 'waiting',
        current_node_label: 'Espera',
        current_node_type: 'wait',
      });

      expect(next[42].workflow_name).toBe('Boas-vindas');
      expect(next[42].status).toBe('waiting');
      expect(existing[42].workflow_name).toBe('Old');
    });

    it('removes the badge when enrollment is no longer in progress', () => {
      const next = applyEnrollmentCableUpdate(existing, {
        conversation_id: 42,
        status: 'completed',
      });
      expect(next[42]).toBeUndefined();
    });
  });
});
