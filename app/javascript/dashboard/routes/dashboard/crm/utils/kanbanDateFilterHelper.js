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
 * Verifica se createdAt (ISO/Date) está dentro do intervalo [dateFrom, dateTo]
 * dos inputs type="date", interpretados no fuso local.
 */
export function matchesKanbanDateRange(createdAt, dateFrom, dateTo) {
  if (!createdAt) return false;

  const createdDate = createdAt instanceof Date ? createdAt : new Date(createdAt);
  if (Number.isNaN(createdDate.getTime())) return false;

  if (dateFrom) {
    const fromDate = startOfLocalDayFromDateInput(dateFrom);
    if (!fromDate || createdDate < fromDate) return false;
  }

  if (dateTo) {
    const toDate = endOfLocalDayFromDateInput(dateTo);
    if (!toDate || createdDate > toDate) return false;
  }

  return true;
}
