/**
 * Parseia valor de <input type="date"> (YYYY-MM-DD) como dia civil no fuso local.
 * Evita new Date("YYYY-MM-DD"), que o ECMAScript trata como meia-noite UTC.
 */

export function parseLocalDateString(dateString) {
  if (!dateString || typeof dateString !== 'string') return null;

  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateString.trim());
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(year, month - 1, day);

  if (
    date.getFullYear() !== year ||
    date.getMonth() !== month - 1 ||
    date.getDate() !== day
  ) {
    return null;
  }

  return date;
}

export function startOfLocalDayFromDateInput(dateString) {
  const date = parseLocalDateString(dateString);
  if (!date) return null;
  date.setHours(0, 0, 0, 0);
  return date;
}

export function endOfLocalDayFromDateInput(dateString) {
  const date = parseLocalDateString(dateString);
  if (!date) return null;
  date.setHours(23, 59, 59, 999);
  return date;
}

/**
 * Normaliza intervalo invertido (from > to) trocando as datas.
 * Strings YYYY-MM-DD comparam lexicograficamente de forma correta.
 */
export function normalizeKanbanDateRange(dateFrom, dateTo) {
  let from = dateFrom || null;
  let to = dateTo || null;

  if (from && to && from > to) {
    [from, to] = [to, from];
  }

  return { dateFrom: from, dateTo: to };
}

/**
 * Verifica se createdAt (ISO/Date) está dentro do intervalo [dateFrom, dateTo]
 * dos inputs type="date", interpretados no fuso local.
 * Intervalos invertidos são normalizados (swap) antes da comparação.
 */
export function matchesKanbanDateRange(createdAt, dateFrom, dateTo) {
  if (!createdAt) return false;

  const createdDate = createdAt instanceof Date ? createdAt : new Date(createdAt);
  if (Number.isNaN(createdDate.getTime())) return false;

  const { dateFrom: from, dateTo: to } = normalizeKanbanDateRange(dateFrom, dateTo);

  if (from) {
    const fromDate = startOfLocalDayFromDateInput(from);
    if (!fromDate || createdDate < fromDate) return false;
  }

  if (to) {
    const toDate = endOfLocalDayFromDateInput(to);
    if (!toDate || createdDate > toDate) return false;
  }

  return true;
}
