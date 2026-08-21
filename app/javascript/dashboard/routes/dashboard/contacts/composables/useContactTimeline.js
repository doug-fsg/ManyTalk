import { computed, ref, unref } from 'vue';
import ContactTimelineAPI from 'dashboard/api/contactTimeline';
import {
  buildTimelineSummary,
  getFilterCounts,
  groupEventsByDate,
  matchesTimelineFilter,
} from '../helpers/contactTimelineHelper';

const ALL_FILTER = 'all';

export const TIMELINE_EVENT_TYPES = [
  'contact_created',
  'form_submission',
  'pipeline_entered',
  'pipeline_stage',
  'deal_won',
  'deal_lost',
  'activity',
  'note',
  'conversation_started',
  'workflow_started',
  'workflow_cancelled',
  'workflow_completed',
  'workflow_failed',
];

export const TIMELINE_FILTER_OPTIONS = [
  ALL_FILTER,
  'form_submission',
  'pipeline',
  'activity',
  'note',
  'conversation_started',
];

export function useContactTimeline(contactIdRef, options = {}) {
  const localeCode = options.localeCode || ref('en');
  const translate = options.t || (key => key);

  const events = ref([]);
  const meta = ref({ count: 0, currentPage: 1, totalPages: 1 });
  const loading = ref(false);
  const loadingMore = ref(false);
  const error = ref(null);
  const activeFilter = ref(ALL_FILTER);

  const fetchTimeline = async (params = {}) => {
    const contactId = contactIdRef.value;
    if (!contactId) return;

    const append = Boolean(params.append);
    const page = params.page || 1;

    if (append) {
      loadingMore.value = true;
    } else {
      loading.value = true;
    }

    error.value = null;

    try {
      const { data } = await ContactTimelineAPI.get(contactId, {
        ...params,
        page,
        append: undefined,
      });

      const payload = data.payload || [];

      if (append) {
        const existingIds = new Set(events.value.map(event => event.id));
        const merged = payload.filter(event => !existingIds.has(event.id));
        events.value = [...events.value, ...merged];
      } else {
        events.value = payload;
      }

      meta.value = {
        count: data.meta?.count || 0,
        currentPage: data.meta?.current_page || page,
        totalPages: data.meta?.total_pages || 1,
      };
    } catch (fetchError) {
      error.value = fetchError;
      if (!append) {
        events.value = [];
      }
    } finally {
      loading.value = false;
      loadingMore.value = false;
    }
  };

  const loadMore = () => {
    if (loadingMore.value || meta.value.currentPage >= meta.value.totalPages) {
      return Promise.resolve();
    }

    return fetchTimeline({
      page: meta.value.currentPage + 1,
      append: true,
    });
  };

  const filteredEvents = computed(() =>
    events.value.filter(event =>
      matchesTimelineFilter(event, activeFilter.value, ALL_FILTER)
    )
  );

  const groupedEvents = computed(() =>
    groupEventsByDate(
      filteredEvents.value,
      unref(localeCode),
      translate
    )
  );

  const filterCounts = computed(() =>
    getFilterCounts(events.value, TIMELINE_FILTER_OPTIONS, ALL_FILTER)
  );

  const summary = computed(() => buildTimelineSummary(events.value, translate));

  const hasMore = computed(
    () => meta.value.currentPage < meta.value.totalPages
  );

  const firstFormSubmission = computed(() => {
    const submissions = events.value
      .filter(event => event.type === 'form_submission')
      .map(event => ({
        ...event.meta,
        occurred_at: event.occurred_at,
      }));

    if (!submissions.length) return null;

    return submissions.sort(
      (left, right) =>
        new Date(left.occurred_at).getTime() -
        new Date(right.occurred_at).getTime()
    )[0];
  });

  const pipelineEvents = computed(() =>
    events.value.filter(event =>
      matchesTimelineFilter(event, 'pipeline', ALL_FILTER)
    )
  );

  return {
    events,
    meta,
    loading,
    loadingMore,
    error,
    activeFilter,
    filteredEvents,
    groupedEvents,
    filterCounts,
    summary,
    hasMore,
    firstFormSubmission,
    pipelineEvents,
    fetchTimeline,
    loadMore,
    ALL_FILTER,
  };
}
