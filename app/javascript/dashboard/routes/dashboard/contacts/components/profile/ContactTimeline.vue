<script setup>
import { computed, toRef, watch } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import Spinner from 'shared/components/Spinner.vue';
import ContactTimelineEvent from './ContactTimelineEvent.vue';
import ContactTimelineSummary from './ContactTimelineSummary.vue';
import {
  useContactTimeline,
  TIMELINE_FILTER_OPTIONS,
} from '../../composables/useContactTimeline';
import {
  buildTimelineSummary,
  getFilterCounts,
  groupEventsByDate,
  matchesTimelineFilter,
} from '../../helpers/contactTimelineHelper';

const props = defineProps({
  contactId: {
    type: [String, Number],
    required: true,
  },
  accountId: {
    type: [String, Number],
    required: true,
  },
  highlightPipelineId: {
    type: [String, Number],
    default: null,
  },
  compact: {
    type: Boolean,
    default: false,
  },
  externalEvents: {
    type: Array,
    default: null,
  },
  externalLoading: {
    type: Boolean,
    default: null,
  },
  externalLoadingMore: {
    type: Boolean,
    default: false,
  },
  externalHasMore: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'open-activities',
  'open-notes',
  'open-deal',
  'refresh',
  'load-more',
]);

const { t, locale } = useI18n();
const contactIdRef = toRef(props, 'contactId');
const usesExternalEvents = computed(() => props.externalEvents != null);

const {
  loading: internalLoading,
  loadingMore: internalLoadingMore,
  error,
  activeFilter,
  filteredEvents: internalFilteredEvents,
  groupedEvents: internalGroupedEvents,
  filterCounts: internalFilterCounts,
  summary: internalSummary,
  hasMore: internalHasMore,
  fetchTimeline,
  loadMore: internalLoadMore,
  ALL_FILTER,
} = useContactTimeline(contactIdRef, {
  localeCode: locale,
  t,
});

watch(
  contactIdRef,
  () => {
    if (!usesExternalEvents.value) {
      fetchTimeline();
    }
  },
  { immediate: true }
);

const loading = computed(() =>
  usesExternalEvents.value ? props.externalLoading : internalLoading.value
);

const loadingMore = computed(() =>
  usesExternalEvents.value
    ? props.externalLoadingMore
    : internalLoadingMore.value
);

const hasMore = computed(() =>
  usesExternalEvents.value ? props.externalHasMore : internalHasMore.value
);

const sourceEvents = computed(() =>
  usesExternalEvents.value ? props.externalEvents || [] : internalFilteredEvents.value
);

const filteredEvents = computed(() => {
  if (!usesExternalEvents.value) {
    return internalFilteredEvents.value;
  }

  return sourceEvents.value.filter(event =>
    matchesTimelineFilter(event, activeFilter.value, ALL_FILTER)
  );
});

const groupedEvents = computed(() => {
  if (!usesExternalEvents.value) {
    return internalGroupedEvents.value;
  }

  return groupEventsByDate(filteredEvents.value, locale.value, t);
});

const filterCounts = computed(() => {
  if (!usesExternalEvents.value) {
    return internalFilterCounts.value;
  }

  return getFilterCounts(
    props.externalEvents || [],
    TIMELINE_FILTER_OPTIONS,
    ALL_FILTER
  );
});

const summary = computed(() => {
  if (!usesExternalEvents.value) {
    return internalSummary.value;
  }

  return buildTimelineSummary(props.externalEvents || [], t);
});

const filterOptions = computed(() =>
  TIMELINE_FILTER_OPTIONS.map(value => ({
    value,
    label:
      value === ALL_FILTER
        ? t('CONTACT_PROFILE.TIMELINE.FILTERS.ALL')
        : t(`CONTACT_PROFILE.TIMELINE.FILTERS.${value.toUpperCase()}`),
    count: filterCounts.value[value] || 0,
  }))
);

const isLastEventInTimeline = (groupIndex, eventIndex) => {
  const lastGroup = groupedEvents.value[groupedEvents.value.length - 1];
  if (!lastGroup) return true;

  const isLastGroup = groupIndex === groupedEvents.value.length - 1;
  return isLastGroup && eventIndex === lastGroup.events.length - 1;
};

const setFilter = value => {
  activeFilter.value = value;
};

const onOpenActivities = activityId => {
  emit('open-activities', activityId);
};

const onOpenNotes = () => {
  emit('open-notes');
};

const onRefresh = () => {
  if (!usesExternalEvents.value) {
    fetchTimeline();
  } else {
    emit('refresh');
  }
};

const onLoadMore = () => {
  if (!usesExternalEvents.value) {
    internalLoadMore();
  } else {
    emit('load-more');
  }
};

defineExpose({
  refresh: fetchTimeline,
});
</script>

<template>
  <div class="contact-timeline">
    <ContactTimelineSummary
      v-if="!compact && summary && filteredEvents.length"
      :summary="summary"
      :compact="compact"
    />

    <div
      v-if="!compact"
      class="sticky top-0 z-[1] -mx-1 mb-4 flex flex-wrap gap-2 bg-slate-25 px-1 py-2 dark:bg-slate-800"
      role="tablist"
      :aria-label="$t('CONTACT_PROFILE.TIMELINE.FILTER_ARIA')"
    >
      <button
        v-for="option in filterOptions"
        :key="option.value"
        type="button"
        role="tab"
        class="inline-flex items-center gap-1.5 rounded-md px-2.5 py-1 text-xs transition-colors duration-150"
        :class="
          activeFilter === option.value
            ? 'bg-white font-medium text-slate-900 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:text-slate-100 dark:ring-slate-700'
            : 'text-slate-500 hover:bg-white/70 hover:text-slate-700 dark:text-slate-400 dark:hover:bg-slate-900/60 dark:hover:text-slate-200'
        "
        :aria-selected="activeFilter === option.value"
        @click="setFilter(option.value)"
      >
        <span>{{ option.label }}</span>
        <span
          class="rounded-full px-1.5 py-0.5 text-[10px] tabular-nums"
          :class="
            activeFilter === option.value
              ? 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300'
              : 'bg-slate-100/80 text-slate-500 dark:bg-slate-700/80 dark:text-slate-400'
          "
        >
          {{ option.count }}
        </span>
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-10">
      <Spinner />
    </div>

    <div
      v-else-if="error && !usesExternalEvents"
      class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-900/40 dark:bg-red-900/20 dark:text-red-300"
    >
      {{ $t('CONTACT_PROFILE.TIMELINE.LOAD_ERROR') }}
    </div>

    <div
      v-else-if="!filteredEvents.length"
      class="rounded-xl border border-dashed border-slate-300 px-6 py-10 text-center dark:border-slate-600"
    >
      <p class="text-sm font-medium text-slate-700 dark:text-slate-200">
        {{ $t('CONTACT_PROFILE.TIMELINE.EMPTY_TITLE') }}
      </p>
      <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CONTACT_PROFILE.TIMELINE.EMPTY_HINT') }}
      </p>

      <div
        v-if="!compact"
        class="mt-5 flex flex-wrap items-center justify-center gap-2"
      >
        <button
          type="button"
          class="rounded-md border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition-colors hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
          @click="emit('open-deal')"
        >
          {{ $t('CONTACT_PROFILE.TIMELINE.EMPTY_ACTIONS.ADD_PIPELINE') }}
        </button>
        <button
          type="button"
          class="rounded-md border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition-colors hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
          @click="emit('open-activities')"
        >
          {{ $t('CONTACT_PROFILE.TIMELINE.EMPTY_ACTIONS.CREATE_ACTIVITY') }}
        </button>
      </div>
    </div>

    <div v-else>
      <div
        v-for="(group, groupIndex) in groupedEvents"
        :key="group.key"
        class="mb-5 last:mb-0"
      >
        <div
          class="mb-3 flex items-center gap-3"
          role="heading"
          aria-level="3"
        >
          <span
            class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400"
          >
            {{ group.label }}
          </span>
          <span class="h-px flex-1 bg-slate-200 dark:bg-slate-700" />
        </div>

        <ol class="list-none p-0 m-0">
          <ContactTimelineEvent
            v-for="(event, eventIndex) in group.events"
            :key="event.id"
            :event="event"
            :account-id="accountId"
            :contact-id="contactId"
            :is-last="isLastEventInTimeline(groupIndex, eventIndex)"
            @open-activities="onOpenActivities"
            @open-notes="onOpenNotes"
            @refresh="onRefresh"
          />
        </ol>
      </div>

      <div v-if="hasMore" class="mt-2 flex justify-center">
        <button
          type="button"
          class="inline-flex items-center gap-2 rounded-md border border-slate-200 bg-white px-4 py-2 text-xs font-medium text-slate-700 transition-colors hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
          :disabled="loadingMore"
          @click="onLoadMore"
        >
          <Spinner v-if="loadingMore" size="tiny" />
          <span>{{ $t('CONTACT_PROFILE.TIMELINE.LOAD_MORE') }}</span>
        </button>
      </div>
    </div>
  </div>
</template>
