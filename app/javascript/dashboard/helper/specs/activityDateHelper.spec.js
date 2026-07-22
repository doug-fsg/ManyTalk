import { formatActivityDateTime, isActivityOverdue } from 'dashboard/helper/activityDateHelper';

describe('activityDateHelper', () => {
  describe('formatActivityDateTime', () => {
    it('returns dash for empty value', () => {
      expect(formatActivityDateTime(null)).toBe('—');
    });

    it('formats ISO date strings', () => {
      expect(formatActivityDateTime('2026-07-21T14:30:00.000Z')).toMatch(
        /21\/07\/2026/
      );
    });
  });

  describe('isActivityOverdue', () => {
    it('returns true for pending activities in the past', () => {
      expect(
        isActivityOverdue({
          status: 'pending',
          scheduled_at: '2020-01-01T10:00:00.000Z',
        })
      ).toBe(true);
    });

    it('returns false for completed activities', () => {
      expect(
        isActivityOverdue({
          status: 'completed',
          scheduled_at: '2020-01-01T10:00:00.000Z',
        })
      ).toBe(false);
    });
  });
});
