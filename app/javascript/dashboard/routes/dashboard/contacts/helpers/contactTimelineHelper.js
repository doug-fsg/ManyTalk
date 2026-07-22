import {
  format,
  formatDistanceToNow,
  fromUnixTime,
  isSameYear,
  isToday,
  isYesterday,
  parseISO,
  startOfDay,
} from 'date-fns';
import { ptBR, enUS } from 'date-fns/locale';

export const PIPELINE_EVENT_TYPES = new Set([
  'pipeline_entered',
  'pipeline_stage_changed',
  'pipeline_reopened',
  'pipeline_stage',
  'deal_won',
  'deal_lost',
]);

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

export function formatTimelineRelativeTime(unixTime, localeCode = 'en') {
  return formatDistanceToNow(fromUnixTime(unixTime), {
    addSuffix: true,
    locale: resolveDateFnsLocale(localeCode),
  });
}

export function formatTimelineAbsoluteTime(unixTime, localeCode = 'en') {
  const messageTime = fromUnixTime(unixTime);
  const locale = resolveDateFnsLocale(localeCode);
  const isPortuguese = normalizeLocaleCode(localeCode) === 'pt_BR';

  if (!isSameYear(messageTime, new Date())) {
    return isPortuguese
      ? format(messageTime, "d 'de' MMMM 'de' yyyy 'às' HH:mm", { locale })
      : format(messageTime, 'LLL d, yyyy, h:mm a', { locale });
  }

  return isPortuguese
    ? format(messageTime, "d 'de' MMMM 'às' HH:mm", { locale })
    : format(messageTime, 'LLL d, h:mm a', { locale });
}

function formatTimelineDateTime(dateString, localeCode = 'en') {
  const locale = resolveDateFnsLocale(localeCode);
  const isPortuguese = normalizeLocaleCode(localeCode) === 'pt_BR';

  return format(
    parseISO(dateString),
    isPortuguese ? "dd/MM/yyyy 'às' HH:mm" : 'MMM d, yyyy, h:mm a',
    { locale }
  );
}

export function getEventUnixTime(event) {
  return Math.floor(new Date(event.occurred_at).getTime() / 1000);
}

export function formatTimelineDateHeader(occurredAt, localeCode, t) {
  const date = parseISO(occurredAt);
  const locale = resolveDateFnsLocale(localeCode);

  if (isToday(date)) {
    return t('CONTACT_PROFILE.TIMELINE.DATE_TODAY');
  }

  if (isYesterday(date)) {
    return t('CONTACT_PROFILE.TIMELINE.DATE_YESTERDAY');
  }

  const isPortuguese = normalizeLocaleCode(localeCode) === 'pt_BR';

  return format(
    date,
    isPortuguese ? "d 'de' MMMM 'de' yyyy" : 'PPP',
    { locale }
  );
}

export function groupEventsByDate(events, localeCode, t) {
  if (!events?.length) {
    return [];
  }

  const sorted = [...events].sort(
    (left, right) =>
      new Date(right.occurred_at).getTime() -
      new Date(left.occurred_at).getTime()
  );

  const groups = [];
  let currentKey = null;

  sorted.forEach(event => {
    const dayKey = format(startOfDay(parseISO(event.occurred_at)), 'yyyy-MM-dd');

    if (dayKey !== currentKey) {
      currentKey = dayKey;
      groups.push({
        key: dayKey,
        label: formatTimelineDateHeader(event.occurred_at, localeCode, t),
        events: [],
      });
    }

    groups[groups.length - 1].events.push(event);
  });

  return groups;
}

export function matchesTimelineFilter(event, filter, allFilter) {
  if (filter === allFilter) {
    return true;
  }

  if (filter === 'pipeline') {
    return PIPELINE_EVENT_TYPES.has(event.type);
  }

  return event.type === filter;
}

export function getFilterCounts(events, filterOptions, allFilter) {
  const counts = { [allFilter]: events.length };

  filterOptions.forEach(filter => {
    if (filter === allFilter) {
      return;
    }

    counts[filter] = events.filter(event =>
      matchesTimelineFilter(event, filter, allFilter)
    ).length;
  });

  return counts;
}

export function buildTimelineSummary(events, t) {
  if (!events?.length) {
    return null;
  }

  const sorted = [...events].sort(
    (left, right) =>
      new Date(right.occurred_at).getTime() -
      new Date(left.occurred_at).getTime()
  );

  const firstForm = sorted
    .filter(event => event.type === 'form_submission')
    .sort(
      (left, right) =>
        new Date(left.occurred_at).getTime() -
        new Date(right.occurred_at).getTime()
    )[0];

  const latestInteraction = sorted.find(event =>
    ['conversation_started', 'activity', 'note'].includes(event.type)
  );

  const nextActivity = sorted
    .filter(
      event =>
        event.type === 'activity' &&
        event.meta?.status === 'pending' &&
        event.meta?.timeline_moment !== 'completed'
    )
    .sort(
      (left, right) =>
        new Date(left.meta?.scheduled_at || left.occurred_at).getTime() -
        new Date(right.meta?.scheduled_at || right.occurred_at).getTime()
    )[0];

  const pipelineEntered = sorted.find(event => event.type === 'pipeline_entered');

  return {
    firstContactLabel: firstForm
      ? t('CONTACT_PROFILE.TIMELINE.SUMMARY.VIA_FORM', {
          form:
            firstForm.meta?.account_form_name ||
            t('CONTACT_PROFILE.TIMELINE.UNKNOWN_FORM'),
        })
      : t('CONTACT_PROFILE.TIMELINE.SUMMARY.CONTACT_CREATED'),
    lastInteractionLabel: latestInteraction
      ? summarizeInteraction(latestInteraction, t)
      : t('CONTACT_PROFILE.TIMELINE.SUMMARY.NO_INTERACTION'),
    nextActivityLabel: nextActivity
      ? t('CONTACT_PROFILE.TIMELINE.SUMMARY.NEXT_ACTIVITY', {
          title:
            nextActivity.meta?.title ||
            t('CONTACT_PROFILE.TIMELINE.EVENTS.ACTIVITY'),
        })
      : null,
    pipelineLabel: pipelineEntered
      ? t('CONTACT_PROFILE.TIMELINE.SUMMARY.IN_PIPELINE', {
          pipeline: pipelineEntered.meta?.pipeline_name,
        })
      : null,
  };
}

function summarizeInteraction(event, t) {
  switch (event.type) {
    case 'conversation_started':
      return t('CONTACT_PROFILE.TIMELINE.SUMMARY.LAST_CONVERSATION', {
        inbox:
          event.meta?.inbox_name ||
          t('CONTACT_PROFILE.TIMELINE.UNKNOWN_INBOX'),
      });
    case 'activity':
      return t('CONTACT_PROFILE.TIMELINE.SUMMARY.LAST_ACTIVITY', {
        title:
          event.meta?.title || t('CONTACT_PROFILE.TIMELINE.EVENTS.ACTIVITY'),
      });
    case 'note':
      return t('CONTACT_PROFILE.TIMELINE.SUMMARY.LAST_NOTE');
    default:
      return t('CONTACT_PROFILE.TIMELINE.SUMMARY.NO_INTERACTION');
  }
}

export function getEventPresentation(event, t, localeCode = 'en') {
  const meta = event.meta || {};

  switch (event.type) {
    case 'contact_created':
      return {
        icon: 'person-add',
        tone: 'neutral',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.CONTACT_CREATED'),
        contextLines: [],
        actionLabel: null,
        isClickable: false,
      };
    case 'form_submission':
      return {
        icon: 'document',
        tone: 'info',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.FORM_SUBMISSION', {
          form:
            meta.account_form_name ||
            t('CONTACT_PROFILE.TIMELINE.UNKNOWN_FORM'),
        }),
        contextLines: meta.utm?.source
          ? [
              t('CONTACT_PROFILE.TIMELINE.UTM_SOURCE', {
                source: meta.utm.source,
              }),
            ]
          : [],
        actionLabel: t('CONTACT_PROFILE.TIMELINE.ACTIONS.VIEW_FORM_CONTACTS'),
        isClickable: !!meta.account_form_id,
      };
    case 'pipeline_entered':
      return {
        icon: 'kanban',
        tone: 'pipeline',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.PIPELINE_ENTERED', {
          pipeline: meta.pipeline_name,
        }),
        contextLines: buildPipelineContext(meta, t),
        actionLabel: t('CONTACT_PROFILE.TIMELINE.ACTIONS.OPEN_PIPELINE'),
        isClickable: !!meta.pipeline_id,
      };
    case 'pipeline_stage_changed':
    case 'pipeline_stage':
      return {
        icon: 'arrow-swap',
        tone: 'pipeline',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.PIPELINE_STAGE_CHANGED', {
          from: meta.from_stage_id || meta.stage_id,
          to: meta.to_stage_id || meta.stage_id,
          pipeline: meta.pipeline_name,
        }),
        contextLines: buildPipelineContext(meta, t),
        actionLabel: t('CONTACT_PROFILE.TIMELINE.ACTIONS.OPEN_PIPELINE'),
        isClickable: !!meta.pipeline_id,
      };
    case 'pipeline_reopened':
      return {
        icon: 'arrow-rotate-counter-clockwise',
        tone: 'pipeline',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.PIPELINE_REOPENED', {
          pipeline: meta.pipeline_name,
        }),
        contextLines: [
          meta.previous_status
            ? t('CONTACT_PROFILE.TIMELINE.REOPENED_FROM', {
                status: meta.previous_status,
              })
            : null,
          ...buildPipelineContext(meta, t),
        ].filter(Boolean),
        actionLabel: t('CONTACT_PROFILE.TIMELINE.ACTIONS.OPEN_PIPELINE'),
        isClickable: !!meta.pipeline_id,
      };
    case 'deal_won':
      return {
        icon: 'checkmark-circle',
        tone: 'success',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.DEAL_WON', {
          pipeline: meta.pipeline_name,
        }),
        contextLines: [
          meta.deal_value
            ? t('CONTACT_PROFILE.TIMELINE.DEAL_VALUE', {
                value: formatDealValue(meta.deal_value),
              })
            : null,
          meta.win_lost_notes,
          ...buildPipelineContext(meta, t),
        ].filter(Boolean),
        actionLabel: t('CONTACT_PROFILE.TIMELINE.ACTIONS.OPEN_PIPELINE'),
        isClickable: !!meta.pipeline_id,
      };
    case 'deal_lost':
      return {
        icon: 'dismiss-circle',
        tone: 'danger',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.DEAL_LOST', {
          pipeline: meta.pipeline_name,
        }),
        contextLines: [
          meta.win_lost_notes,
          ...buildPipelineContext(meta, t),
        ].filter(Boolean),
        actionLabel: t('CONTACT_PROFILE.TIMELINE.ACTIONS.OPEN_PIPELINE'),
        isClickable: !!meta.pipeline_id,
      };
    case 'activity':
      return {
        icon:
          meta.timeline_moment === 'completed'
            ? 'checkmark-circle'
            : 'calendar-clock',
        tone: meta.timeline_moment === 'completed' ? 'success' : 'warning',
        title:
          meta.timeline_moment === 'completed'
            ? t('CONTACT_PROFILE.TIMELINE.EVENTS.ACTIVITY_COMPLETED', {
                title:
                  meta.title || t('CONTACT_PROFILE.TIMELINE.EVENTS.ACTIVITY'),
              })
            : meta.title || t('CONTACT_PROFILE.TIMELINE.EVENTS.ACTIVITY'),
        contextLines: buildActivityContext(meta, t, localeCode),
        actionLabel: t('CONTACT_PROFILE.TIMELINE.ACTIONS.VIEW_ACTIVITY'),
        isClickable: !!meta.activity_id,
      };
    case 'note':
      return {
        icon: 'clipboard',
        tone: 'neutral',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.NOTE', {
          user:
            meta.user_name || t('CONTACT_PROFILE.TIMELINE.UNKNOWN_USER'),
        }),
        contextLines: meta.content ? [truncateText(meta.content, 140)] : [],
        actionLabel: null,
        isClickable: false,
      };
    case 'conversation_started':
      return {
        icon: 'chat',
        tone: 'brand',
        title: t('CONTACT_PROFILE.TIMELINE.EVENTS.CONVERSATION', {
          inbox:
            meta.inbox_name || t('CONTACT_PROFILE.TIMELINE.UNKNOWN_INBOX'),
        }),
        contextLines: [],
        actionLabel: t('CONTACT_PROFILE.TIMELINE.ACTIONS.OPEN_CONVERSATION'),
        isClickable: !!(meta.conversation_internal_id || meta.conversation_id),
      };
    default:
      return {
        icon: 'info',
        tone: 'neutral',
        title: event.type,
        contextLines: [],
        actionLabel: null,
        isClickable: false,
      };
  }
}

function buildPipelineContext(meta, t) {
  const lines = [];

  if (meta.assignee_name) {
    lines.push(
      t('CONTACT_PROFILE.TIMELINE.ASSIGNEE', { name: meta.assignee_name })
    );
  }

  if (meta.user_name) {
    lines.push(
      t('CONTACT_PROFILE.TIMELINE.PERFORMED_BY', { name: meta.user_name })
    );
  }

  return lines;
}

function buildActivityContext(meta, t, localeCode = 'en') {
  const lines = [];

  if (meta.description) {
    lines.push(meta.description);
  }

  if (meta.status && meta.timeline_moment !== 'completed') {
    lines.push(t(`ACTIVITIES.STATUS.${meta.status.toUpperCase()}`));
  }

  if (meta.timeline_moment === 'completed' && meta.scheduled_at) {
    lines.push(
      t('CONTACT_PROFILE.TIMELINE.SCHEDULED_FOR', {
        date: formatTimelineDateTime(meta.scheduled_at, localeCode),
      })
    );
  } else if (meta.scheduled_at) {
    lines.push(
      t('CONTACT_PROFILE.TIMELINE.SCHEDULED_FOR', {
        date: formatTimelineDateTime(meta.scheduled_at, localeCode),
      })
    );
  }

  if (meta.assignee_name) {
    lines.push(
      t('CONTACT_PROFILE.TIMELINE.ASSIGNEE', { name: meta.assignee_name })
    );
  }

  if (meta.user_name) {
    lines.push(
      t('CONTACT_PROFILE.TIMELINE.PERFORMED_BY', { name: meta.user_name })
    );
  }

  return lines.filter(Boolean);
}

function truncateText(value, maxLength) {
  const normalized = String(value).replace(/\s+/g, ' ').trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }

  return `${normalized.slice(0, maxLength).trim()}…`;
}

function formatDealValue(value) {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(Number(value));
}

export const EVENT_TONE_CLASSES = {
  neutral:
    'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-200',
  info: 'bg-blue-50 text-blue-600 dark:bg-blue-900/30 dark:text-blue-300',
  pipeline:
    'bg-amber-50 text-amber-700 dark:bg-amber-900/20 dark:text-amber-300',
  success:
    'bg-green-50 text-green-700 dark:bg-green-900/20 dark:text-green-300',
  danger: 'bg-red-50 text-red-600 dark:bg-red-900/20 dark:text-red-300',
  warning:
    'bg-yellow-50 text-yellow-700 dark:bg-yellow-900/20 dark:text-yellow-300',
  brand: 'bg-woot-50 text-woot-600 dark:bg-woot-900/30 dark:text-woot-300',
};
