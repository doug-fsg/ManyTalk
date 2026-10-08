<template>
  <span
    v-if="summary"
    class="workflow-enrollment-badge tooltip-container relative inline-flex shrink-0"
    @click.stop
  >
    <span
      class="inline-flex shrink-0 items-center gap-0.5 py-0.5 text-xs font-medium rounded-full bg-teal-50 text-teal-800 ring-1 ring-inset ring-teal-200/90 dark:bg-teal-950/70 dark:text-teal-100 dark:ring-teal-700/80"
      :class="badgeLabel ? 'px-1.5' : 'px-1'"
      :aria-label="accessibleSummary"
      tabindex="0"
    >
      <fluent-icon
        icon="send-clock"
        size="12"
        class="shrink-0"
        aria-hidden="true"
      />
      <span
        v-if="badgeLabel"
        class="tabular-nums leading-none"
      >
        {{ badgeLabel }}
      </span>
    </span>

    <div
      class="workflow-enrollment-badge__popover tooltip-content"
      role="tooltip"
    >
      <p
        v-if="enrollmentStatusLabel"
        class="inline-flex items-center px-2 py-0.5 mb-2 rounded-full text-xs font-medium"
        :class="statusPopoverClass"
      >
        {{ enrollmentStatusLabel }}
      </p>

      <div class="mb-2">
        <span class="font-semibold text-slate-300">
          {{ $t('WORKFLOW.REGUA.WORKFLOW_LABEL') }}
        </span>
        <p class="mt-0.5 text-white break-words line-clamp-3">
          {{ summary.workflow_name }}
        </p>
      </div>

      <div
        v-if="stageLabel && stageLabel !== '—'"
        class="mb-2"
      >
        <span class="font-semibold text-slate-300">
          {{ $t('WORKFLOW.REGUA.STAGE_LABEL') }}
        </span>
        <p class="mt-0.5 text-white break-words line-clamp-2">
          {{ stageLabel }}
        </p>
      </div>

      <p
        v-if="stepProgressLabel"
        class="text-slate-300 text-xs tabular-nums"
      >
        {{ stepProgressLabel }}
      </p>

      <div class="tooltip-arrow" />
    </div>
  </span>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { displayWorkflowStepLabel } from 'dashboard/helper/workflowDisplayLabels';

const props = defineProps({
  summary: { type: Object, default: null },
});

const { t } = useI18n();

const STATUS_POPOVER_CLASS = {
  active:
    'bg-green-500/20 text-green-200',
  waiting:
    'bg-violet-500/20 text-violet-200',
  paused:
    'bg-amber-500/20 text-amber-200',
};

const stageLabel = computed(() =>
  displayWorkflowStepLabel(
    {
      label: props.summary?.current_node_label,
      type: props.summary?.current_node_type,
    },
    t
  )
);

const enrollmentStatusLabel = computed(() => {
  const status = props.summary?.status;
  if (!status) return '';
  const key = `WORKFLOW.REGUA.STATUS_${status.toUpperCase()}`;
  const translated = t(key);
  return translated !== key ? translated : status;
});

const statusPopoverClass = computed(
  () =>
    STATUS_POPOVER_CLASS[props.summary?.status] ||
    STATUS_POPOVER_CLASS.active
);

const badgeLabel = computed(() => {
  const { step_index: current, total_steps: total } = props.summary || {};
  if (current && total) return `${current}/${total}`;
  return '';
});

const stepProgressLabel = computed(() => {
  const { step_index: current, total_steps: total } = props.summary || {};
  if (!current || !total) return '';
  return t('WORKFLOW.REGUA.BADGE_TOOLTIP_STEP', {
    current,
    total,
  });
});

const accessibleSummary = computed(() => {
  const parts = [t('WORKFLOW.REGUA.TITLE')];
  const status = enrollmentStatusLabel.value;
  if (status) parts.push(status);
  if (badgeLabel.value) parts.push(badgeLabel.value);
  return parts.join(', ');
});
</script>

<style scoped>
.tooltip-container {
  position: relative;
}

.tooltip-content {
  position: absolute;
  top: calc(100% + 0.5rem);
  left: 0;
  z-index: 50;
  padding: 0.75rem 1rem;
  font-size: 0.75rem;
  line-height: 1.35;
  background-color: #1e293b;
  color: white;
  border-radius: 0.5rem;
  box-shadow:
    0 10px 15px -3px rgba(0, 0, 0, 0.1),
    0 4px 6px -2px rgba(0, 0, 0, 0.05);
  width: max-content;
  max-width: 16rem;
  white-space: normal;
  opacity: 0;
  visibility: hidden;
  transition:
    opacity 0.15s ease-in-out,
    visibility 0.15s ease-in-out;
  pointer-events: none;
}

.tooltip-arrow {
  position: absolute;
  top: -0.25rem;
  left: 1rem;
  transform: rotate(45deg);
  width: 0.5rem;
  height: 0.5rem;
  background-color: #1e293b;
}

.tooltip-container:hover .tooltip-content,
.tooltip-container:focus-within .tooltip-content {
  opacity: 1;
  visibility: visible;
}

@media (prefers-color-scheme: dark) {
  .tooltip-content {
    background-color: #0f172a;
  }

  .tooltip-arrow {
    background-color: #0f172a;
  }
}
</style>
