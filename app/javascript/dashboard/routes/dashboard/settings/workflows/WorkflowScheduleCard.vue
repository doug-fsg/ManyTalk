<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  schedule: { type: Object, required: true },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['toggle', 'edit', 'delete']);
const { t } = useI18n();

const weekdayLabel = computed(() =>
  t(`WORKFLOW.SCHEDULES.WEEKDAYS.${props.schedule.weekday}`)
);

const timeLabel = computed(() => {
  const hour = String(props.schedule.hour ?? 0).padStart(2, '0');
  const minute = String(props.schedule.minute ?? 0).padStart(2, '0');
  return `${hour}:${minute}`;
});

const nextRunLabel = computed(() => {
  if (!props.schedule.next_run_at) return t('WORKFLOW.SCHEDULES.NEXT_EMPTY');
  return t('WORKFLOW.SCHEDULES.NEXT_AT', {
    date: new Date(props.schedule.next_run_at).toLocaleString(),
  });
});

const lastStats = computed(() => props.schedule.last_run_stats || {});

const statusLabel = computed(() =>
  props.schedule.active
    ? t('WORKFLOW.LIST.ACTIVE')
    : t('WORKFLOW.LIST.INACTIVE')
);

const toggle = () => {
  emit('toggle', {
    id: props.schedule.id,
    activating: !props.schedule.active,
  });
};
</script>

<template>
  <div
    class="flex flex-col h-full min-w-0 p-5 bg-white border border-solid rounded-xl dark:bg-slate-800 border-slate-75 dark:border-slate-700/50 shadow-soft"
  >
    <div class="flex items-start justify-between gap-3 mb-3">
      <div class="min-w-0 flex-1">
        <h3
          class="text-base font-semibold text-slate-800 dark:text-slate-100 truncate"
          :title="schedule.name"
        >
          {{ schedule.name }}
        </h3>
        <p class="mt-1 text-sm text-slate-600 dark:text-slate-300 truncate">
          {{ schedule.workflow_name }}
        </p>
      </div>
      <woot-switch
        class="shrink-0 mt-0.5"
        :value="schedule.active"
        @input="toggle"
      />
    </div>

    <div class="flex flex-wrap items-center gap-2 mb-3">
      <span
        class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md"
        :class="
          schedule.active
            ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300'
            : 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300'
        "
      >
        {{ statusLabel }}
      </span>
      <span
        class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
      >
        {{ weekdayLabel }} · {{ timeLabel }}
      </span>
    </div>

    <p class="text-sm text-slate-600 dark:text-slate-300 mb-1">
      {{ schedule.pipeline_name }} · {{ schedule.stage_id }}
    </p>
    <p class="text-xs text-slate-500 dark:text-slate-400 mb-4">
      {{ nextRunLabel }}
    </p>

    <p
      v-if="schedule.last_run_status"
      class="text-xs text-slate-500 dark:text-slate-400 mb-4"
    >
      {{
        $t('WORKFLOW.SCHEDULES.LAST_RUN', {
          enrolled: lastStats.enrolled || 0,
          skipped: lastStats.skipped || 0,
          failed: lastStats.failed || 0,
        })
      }}
    </p>

    <div
      class="flex items-center justify-end gap-1 mt-auto pt-3 border-t border-slate-50 dark:border-slate-700/50"
    >
      <woot-button
        v-tooltip.top="$t('WORKFLOW.LIST.EDIT')"
        variant="smooth"
        size="tiny"
        color-scheme="secondary"
        icon="edit"
        :is-loading="loading"
        @click="emit('edit', schedule)"
      />
      <woot-button
        v-tooltip.top="$t('WORKFLOW.LIST.DELETE')"
        variant="smooth"
        color-scheme="alert"
        size="tiny"
        icon="dismiss-circle"
        :is-loading="loading"
        @click="emit('delete', schedule)"
      />
    </div>
  </div>
</template>
