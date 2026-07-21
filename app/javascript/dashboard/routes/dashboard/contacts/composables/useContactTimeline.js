import { computed, ref } from 'vue';
import ContactTimelineAPI from 'dashboard/api/contactTimeline';

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
];

export const TIMELINE_FILTER_OPTIONS = [
  ALL_FILTER,
  'form_submission',
  'pipeline',
  'activity',
  'note',
  'conversation_started',
];

const PIPELINE_TYPES = new Set([
  'pipeline_entered',
  'pipeline_stage_changed',
  'pipeline_reopened',
  'deal_won',
  'deal_lost',
]);

export function useContactTimeline(contactIdRef) {
  const events = ref([]);
  const meta = ref({ count: 0, currentPage: 1, totalPages: 1 });
  const loading = ref(false);
  const error = ref(null);
  const activeFilter = ref(ALL_FILTER);

  const fetchTimeline = async (params = {}) => {
    const contactId = contactIdRef.value;
    if (!contactId) return;

    loading.value = true;
    error.value = null;

    try {
      const { data } = await ContactTimelineAPI.get(contactId, params);
      events.value = data.payload || [];
      meta.value = {
        count: data.meta?.count || 0,
        currentPage: data.meta?.current_page || 1,
        totalPages: data.meta?.total_pages || 1,
      };
    } catch (fetchError) {
      error.value = fetchError;
      events.value = [];
    } finally {
      loading.value = false;
    }
  };

  const filteredEvents = computed(() => {
    if (activeFilter.value === ALL_FILTER) {
      return events.value;
    }

    if (activeFilter.value === 'pipeline') {
      return events.value.filter(event => PIPELINE_TYPES.has(event.type));
    }

    return events.value.filter(event => event.type === activeFilter.value);
  });

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
        new Date(left.occurred_at).getTime() - new Date(right.occurred_at).getTime()
    )[0];
  });

  const pipelineEvents = computed(() =>
    events.value.filter(event => PIPELINE_TYPES.has(event.type))
  );

  return {
    events,
    meta,
    loading,
    error,
    activeFilter,
    filteredEvents,
    firstFormSubmission,
    pipelineEvents,
    fetchTimeline,
    ALL_FILTER,
  };
}
