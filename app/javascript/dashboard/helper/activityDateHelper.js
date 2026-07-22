import { format, parseISO } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export function formatActivityDateTime(dateString, locale = ptBR) {
  if (!dateString) return '—';
  const date =
    typeof dateString === 'string' ? parseISO(dateString) : dateString;
  return format(date, "d/MM/yyyy 'às' HH:mm", { locale });
}

export function isActivityOverdue(activity) {
  if (!activity || activity.status !== 'pending' || !activity.scheduled_at) {
    return false;
  }
  return new Date(activity.scheduled_at).getTime() < Date.now();
}

export const ACTIVITY_STATUS_FILTER_OPTIONS = [
  { value: 'all', labelKey: 'ACTIVITIES.FILTERS.ALL' },
  { value: 'pending', labelKey: 'ACTIVITIES.STATUS.PENDING' },
  { value: 'completed', labelKey: 'ACTIVITIES.STATUS.COMPLETED' },
  { value: 'overdue', labelKey: 'ACTIVITIES.FILTERS.OVERDUE' },
];
