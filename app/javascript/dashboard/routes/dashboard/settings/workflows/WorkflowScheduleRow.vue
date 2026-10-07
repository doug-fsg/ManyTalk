<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  schedule: { type: Object, required: true },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['toggle', 'edit', 'delete']);
const { t } = useI18n();

const timeLabel = computed(() => {
  const hour = String(props.schedule.hour ?? 0).padStart(2, '0');
  const minute = String(props.schedule.minute ?? 0).padStart(2, '0');
  return `${hour}:${minute}`;
});

const cadenceLabel = computed(() => {
  if (props.schedule.recurring === false) {
    return t('WORKFLOW.SCHEDULES.CADENCE_ONCE');
  }
  return t('WORKFLOW.SCHEDULES.WEEKDAYS.' + props.schedule.weekday);
});

const whenLabel = computed(() => `${cadenceLabel.value} · ${timeLabel.value}`);

const audienceCount = computed(() => {
  const count = props.schedule.audience_count;
  return count == null ? 0 : count;
});

const nextRunLabel = computed(() => {
  if (
    props.schedule.recurring === false &&
    !props.schedule.active &&
    props.schedule.last_run_status
  ) {
    return t('WORKFLOW.SCHEDULES.ONCE_DONE');
  }
  if (!props.schedule.next_run_at) return t('WORKFLOW.SCHEDULES.NEXT_EMPTY');
  return new Date(props.schedule.next_run_at).toLocaleString();
});
</script>

<template>
  <tr>
    <td class="py-4 ltr:pr-4 rtl:pl-4 align-middle">
      <p class="font-medium text-slate-800 dark:text-slate-100">
        {{ schedule.name }}
      </p>
      <p class="text-xs text-slate-500 dark:text-slate-400">
        {{ schedule.workflow_name }}
      </p>
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4 align-middle">
      {{ schedule.pipeline_name }} · {{ schedule.stage_id }}
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4 align-middle tabular-nums">
      {{ audienceCount }}
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4 align-middle">
      {{ whenLabel }}
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4 align-middle text-xs text-slate-500 dark:text-slate-400">
      {{ nextRunLabel }}
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4 align-middle">
      <woot-switch
        :value="schedule.active"
        @input="emit('toggle', { id: schedule.id, activating: !schedule.active })"
      />
    </td>
    <td class="py-4 align-middle">
      <div class="flex items-center justify-end gap-1">
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
    </td>
  </tr>
</template>
