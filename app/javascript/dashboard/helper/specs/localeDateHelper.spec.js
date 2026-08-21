import {
  formatListDate,
  formatListDateTime,
  normalizeLocaleCode,
} from '../localeDateHelper';

describe('localeDateHelper', () => {
  // 2026-08-11 15:30:00 UTC
  const unixSeconds = 1786462200;

  describe('normalizeLocaleCode', () => {
    it('maps portuguese variants to pt_BR', () => {
      expect(normalizeLocaleCode('pt')).toBe('pt_BR');
      expect(normalizeLocaleCode('pt-BR')).toBe('pt_BR');
      expect(normalizeLocaleCode('pt_BR')).toBe('pt_BR');
    });
  });

  describe('formatListDate', () => {
    it('formats in portuguese for pt_BR', () => {
      expect(formatListDate(unixSeconds, 'pt_BR')).toBe('11/08/2026');
    });

    it('formats in english for en', () => {
      expect(formatListDate(unixSeconds, 'en')).toBe('Aug 11, 2026');
    });

    it('returns dash for empty values', () => {
      expect(formatListDate(null, 'pt_BR')).toBe('—');
      expect(formatListDate('', 'en')).toBe('—');
    });
  });

  describe('formatListDateTime', () => {
    it('formats in portuguese for pt_BR', () => {
      expect(formatListDateTime(unixSeconds, 'pt_BR')).toMatch(
        /^11\/08\/2026 às \d{2}:\d{2}$/
      );
    });

    it('formats in english for en', () => {
      expect(formatListDateTime(unixSeconds, 'en')).toMatch(
        /^Aug 11, 2026 \d{2}:\d{2} [AP]M$/
      );
    });
  });
});
