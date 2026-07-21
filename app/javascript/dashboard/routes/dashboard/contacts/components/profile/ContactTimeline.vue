<script setup>
import { computed, toRef, watch } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import Spinner from 'shared/components/Spinner.vue';
import ContactTimelineEvent from './ContactTimelineEvent.vue';
import {
  useContactTimeline,
  TIMELINE_FILTER_OPTIONS,
} from '../../composables/useContactTimeline';

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
});

const emit = defineEmits(['open-activities', 'refresh']);

const { t } = useI18n();
const contactIdRef = toRef(props, 'contactId');
const usesExternalEvents = computed(() => props.externalEvents != null);

const {
  loading: internalLoading,
  error,
  activeFilter,
  filteredEvents: internalFilteredEvents,
  fetchTimeline,
  ALL_FILTER,
} = useContactTimeline(contactIdRef);

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

const filteredEvents = computed(() => {
  if (usesExternalEvents.value) {
    if (activeFilter.value === ALL_FILTER) {
      return props.externalEvents;
    }

    if (activeFilter.value === 'pipeline') {
      return props.externalEvents.filter(event =>
        [
          'pipeline_entered',
          'pipeline_stage_changed',
          'pipeline_reopened',
          'deal_won',
          'deal_lost',
        ].includes(event.type)
      );
    }

    return props.externalEvents.filter(
      event => event.type === activeFilter.value
    );
  }

  return internalFilteredEvents.value;
});

const filterOptions = computed(() =>
  TIMELINE_FILTER_OPTIONS.map(value => ({
    value,
    label:
      value === ALL_FILTER
        ? t('CONTACT_PROFILE.TIMELINE.FILTERS.ALL')
        : t(`CONTACT_PROFILE.TIMELINE.FILTERS.${value.toUpperCase()}`),
  }))
);

const setFilter = value => {
  activeFilter.value = value;
};

const onOpenActivities = activityId => {
  emit('open-activities', activityId);
};

const onRefresh = () => {
  if (!usesExternalEvents.value) {
    fetchTimeline();
  } else {
    emit('refresh');
  }
};

defineExpose({
  refresh: fetchTimeline,
});
</script>

<template>
  <div class="contact-timeline">
    <div
      v-if="!compact"
      class="mb-4 flex flex-wrap gap-2"
      role="tablist"
      :aria-label="$t('CONTACT_PROFILE.TIMELINE.FILTER_ARIA')"
    >
      <button
        v-for="option in filterOptions"
        :key="option.value"
        type="button"
        role="tab"
        class="rounded px-2 py-1 text-xs transition-colors duration-150"
        :class="
          activeFilter === option.value
            ? 'bg-slate-200 font-medium text-slate-800 dark:bg-slate-700 dark:text-slate-100'
            : 'text-slate-500 hover:bg-slate-100 hover:text-slate-700 dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-200'
        "
        :aria-selected="activeFilter === option.value"
        @click="setFilter(option.value)"
      >
        {{ option.label }}
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

    <div v-else-if="!filteredEvents.length" class="py-8 text-center">
      <p class="text-sm text-slate-600 dark:text-slate-300">
        {{ $t('CONTACT_PROFILE.TIMELINE.EMPTY_TITLE') }}
      </p>
      <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CONTACT_PROFILE.TIMELINE.EMPTY_HINT') }}
      </p>
    </div>

    <div v-else>
      <ContactTimelineEvent
        v-for="event in filteredEvents"
        :key="event.id"
        :event="event"
        :account-id="accountId"
        :contact-id="contactId"
        @open-activities="onOpenActivities"
        @refresh="onRefresh"
      />
    </div>
  </div>
</template>
