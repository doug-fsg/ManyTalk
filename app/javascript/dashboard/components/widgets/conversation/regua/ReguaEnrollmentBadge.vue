<template>
  <span
    v-if="summary"
    v-tooltip="tooltipText"
    class="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium rounded-full truncate max-w-[10rem]"
    :class="badgeClass"
  >
    <fluent-icon
      icon="send-clock"
      size="12"
    />
    <span class="truncate">
      {{ badgeLabel }}
    </span>
  </span>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  summary: { type: Object, default: null },
});

const { t } = useI18n();

const STATUS_CLASS = {
  active: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300',
  waiting: 'bg-violet-100 text-violet-700 dark:bg-violet-900/30 dark:text-violet-300',
  paused: 'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300',
};

const badgeClass = computed(
  () => STATUS_CLASS[props.summary?.status] || STATUS_CLASS.active
);

const badgeLabel = computed(() => {
  if (!props.summary) return '';
  const label = props.summary.current_node_label;
  return label
    ? `${t('WORKFLOW.REGUA.BADGE_PREFIX')} · ${label}`
    : t('WORKFLOW.REGUA.BADGE_PREFIX');
});

const tooltipText = computed(() => {
  if (!props.summary) return '';
  const parts = [props.summary.workflow_name];
  if (props.summary.step_index && props.summary.total_steps) {
    parts.push(
      t('WORKFLOW.REGUA.BADGE_TOOLTIP_STEP', {
        current: props.summary.step_index,
        total: props.summary.total_steps,
      })
    );
  }
  return parts.join(' — ');
});
</script>
