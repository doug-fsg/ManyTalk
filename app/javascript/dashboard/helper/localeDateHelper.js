import { format, fromUnixTime } from 'date-fns';
import { enUS, ptBR } from 'date-fns/locale';

const LOCALE_MAP = {
  pt_BR: ptBR,
  en: enUS,
};

export function normalizeLocaleCode(localeCode = 'en') {
  if (!localeCode) {
    return 'en';
  }

  const normalized = String(localeCode).replace('-', '_');

  if (normalized.startsWith('pt')) {
    return 'pt_BR';
  }

  if (normalized.startsWith('en')) {
    return 'en';
  }

  return normalized;
}

export function resolveDateFnsLocale(localeCode = 'en') {
  return LOCALE_MAP[normalizeLocaleCode(localeCode)] || enUS;
}

/**
 * Formats a unix timestamp (seconds) for settings list date columns.
 * pt-BR: 11/08/2026 · en: Aug 11, 2026
 */
export function formatListDate(unixSeconds, localeCode = 'en') {
  if (unixSeconds == null || unixSeconds === '') {
    return '—';
  }

  const date = fromUnixTime(Number(unixSeconds));
  const isPortuguese = normalizeLocaleCode(localeCode) === 'pt_BR';

  return format(date, isPortuguese ? 'dd/MM/yyyy' : 'LLL d, yyyy', {
    locale: resolveDateFnsLocale(localeCode),
  });
}

/**
 * Formats a unix timestamp (seconds) for list date tooltips.
 * pt-BR: 11/08/2026 às 14:30 · en: Aug 11, 2026 02:30 PM
 */
export function formatListDateTime(unixSeconds, localeCode = 'en') {
  if (unixSeconds == null || unixSeconds === '') {
    return '';
  }

  const date = fromUnixTime(Number(unixSeconds));
  const isPortuguese = normalizeLocaleCode(localeCode) === 'pt_BR';

  return format(
    date,
    isPortuguese ? "dd/MM/yyyy 'às' HH:mm" : 'LLL d, yyyy hh:mm a',
    { locale: resolveDateFnsLocale(localeCode) }
  );
}

export function formatBillingDate(isoDate, localeCode = 'en') {
  if (!isoDate) return '';

  const date = new Date(isoDate);
  const isPortuguese = normalizeLocaleCode(localeCode) === 'pt_BR';

  return format(
    date,
    isPortuguese ? 'dd/MM/yyyy' : 'dd MMM, yyyy',
    { locale: resolveDateFnsLocale(localeCode) }
  );
}
