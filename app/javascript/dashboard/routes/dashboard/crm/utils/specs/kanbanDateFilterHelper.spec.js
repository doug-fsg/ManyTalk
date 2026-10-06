/**
 * @vitest-environment node
 */
import {
  endOfLocalDayFromDateInput,
  matchesKanbanDateRange,
  parseLocalDateString,
  startOfLocalDayFromDateInput,
} from '../kanbanDateFilterHelper';

describe('kanbanDateFilterHelper', () => {
  const originalTZ = process.env.TZ;

  beforeAll(() => {
    process.env.TZ = 'America/Sao_Paulo';
  });

  afterAll(() => {
    process.env.TZ = originalTZ;
  });

  describe('parseLocalDateString', () => {
    it('parses YYYY-MM-DD as local midnight, not UTC', () => {
      const date = parseLocalDateString('2026-10-06');
      expect(date.getFullYear()).toBe(2026);
      expect(date.getMonth()).toBe(9);
      expect(date.getDate()).toBe(6);
      expect(date.getHours()).toBe(0);
    });

    it('does not shift to previous day in UTC-3', () => {
      // Bug antigo: new Date("2026-10-06") => 05/10 21:00 BRT
      const buggy = new Date('2026-10-06');
      expect(buggy.getDate()).toBe(5);

      const fixed = parseLocalDateString('2026-10-06');
      expect(fixed.getDate()).toBe(6);
    });
  });

  describe('start/end of local day', () => {
    it('builds full local day bounds for date input', () => {
      const from = startOfLocalDayFromDateInput('2026-10-06');
      const to = endOfLocalDayFromDateInput('2026-10-06');

      expect(from.toString()).toContain('Oct 06 2026 00:00:00');
      expect(to.getDate()).toBe(6);
      expect(to.getHours()).toBe(23);
      expect(to.getMinutes()).toBe(59);
    });
  });

  describe('matchesKanbanDateRange', () => {
    it('includes cards created on the selected local day', () => {
      // 06/10 00:00 BRT
      expect(
        matchesKanbanDateRange('2026-10-06T03:00:00.000Z', '2026-10-06', '2026-10-06')
      ).toBe(true);
      // 06/10 09:00 BRT
      expect(
        matchesKanbanDateRange('2026-10-06T12:00:00.000Z', '2026-10-06', '2026-10-06')
      ).toBe(true);
    });

    it('excludes previous local day that UTC parse would wrongly include', () => {
      // 05/10 23:59 BRT — entrava com o bug
      expect(
        matchesKanbanDateRange('2026-10-06T02:59:59.999Z', '2026-10-06', '2026-10-06')
      ).toBe(false);
      expect(
        matchesKanbanDateRange('2026-10-05T15:00:00.000Z', '2026-10-06', '2026-10-06')
      ).toBe(false);
    });

    it('returns false when createdAt is missing', () => {
      expect(matchesKanbanDateRange(null, '2026-10-06', null)).toBe(false);
    });
  });
});
