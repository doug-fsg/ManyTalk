<template>
  <div class="border-t border-slate-75 dark:border-slate-700 pt-4">
    <ol class="space-y-0">
      <li
        v-for="(item, index) in timeline"
        :key="item.node_id || index"
        class="relative flex gap-3 pb-3 last:pb-0"
      >
        <div class="flex flex-col items-center">
          <span
            class="w-2 h-2 rounded-full shrink-0"
            :class="dotClass(item)"
          />
          <span
            v-if="index < timeline.length - 1"
            class="w-px flex-1 min-h-[1rem] bg-slate-75 dark:bg-slate-600"
          />
        </div>
        <div class="flex-1 min-w-0 -mt-0.5">
          <div class="flex items-center gap-1 min-w-0">
            <p
              class="text-sm truncate min-w-0"
              :class="labelClass(item)"
            >
              {{ stepLabel(item) }}
            </p>
            <button
              v-if="actionDetailsText(item)"
              v-tooltip.top="actionDetailsTooltip(item)"
              type="button"
              class="inline-flex shrink-0 items-center justify-center p-0.5 rounded text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-woot-500"
              :aria-label="$t('WORKFLOW.REGUA.TIMELINE.ACTION_DETAILS')"
            >
              <fluent-icon icon="info" size="14" aria-hidden="true" />
            </button>
          </div>
          <p
            class="text-xs tabular-nums"
            :class="item.status === 'failed' ? 'text-red-500 dark:text-red-400' : 'text-slate-500 dark:text-slate-400'"
          >
            {{ statusLabel(item) }}
          </p>
          <p
            v-if="item.status === 'failed' && item.error_message"
            class="text-xs text-red-500 dark:text-red-400 mt-0.5 break-words"
            :title="item.error_message"
          >
            {{ item.error_message }}
          </p>
        </div>
      </li>
    </ol>
  </div>
</template>

<script setup>
import { useI18n } from 'dashboard/composables/useI18n';
import {
  displayTimelineStatus,
  displayWorkflowStepLabel,
} from 'dashboard/helper/workflowDisplayLabels';
import {
  actionDetailsTextForItem,
  actionDetailsTooltipForItem,
} from './reguaTimelineHelpers';

const props = defineProps({
  timeline: { type: Array, default: () => [] },
  currentNodeId: { type: String, default: null },
});

const { t } = useI18n();

const stepLabel = item => displayWorkflowStepLabel(item, t);

const actionDetailsText = actionDetailsTextForItem;
const actionDetailsTooltip = actionDetailsTooltipForItem;

const dotClass = item => {
  if (item.node_id === props.currentNodeId) return 'bg-woot-500';
  if (item.status === 'completed') return 'bg-green-500';
  if (item.status === 'failed') return 'bg-red-500';
  if (item.status === 'skipped') return 'bg-slate-200 dark:bg-slate-600';
  if (item.status === 'scheduled') return 'bg-violet-400';
  return 'bg-slate-300 dark:bg-slate-500';
};

const labelClass = item => {
  if (item.node_id === props.currentNodeId) return 'font-medium text-woot-500';
  if (item.status === 'failed') return 'text-red-600 dark:text-red-400';
  if (item.status === 'skipped') return 'text-slate-400 dark:text-slate-500 line-through';
  return 'text-slate-800 dark:text-slate-100';
};

const statusLabel = item => {
  if (item.node_id === props.currentNodeId) {
    return t('WORKFLOW.REGUA.TIMELINE.NOW');
  }
  if (item.status === 'failed') {
    return t('WORKFLOW.REGUA.TIMELINE.FAILED');
  }
  if (item.status === 'skipped') {
    return t('WORKFLOW.REGUA.TIMELINE.SKIPPED');
  }
  if (item.scheduled_at) {
    try {
      const formatted = new Intl.DateTimeFormat(undefined, {
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(new Date(item.scheduled_at));
      return `${t('WORKFLOW.REGUA.TIMELINE.PENDING')} — ${formatted}`;
    } catch {
      return t('WORKFLOW.REGUA.TIMELINE.PENDING');
    }
  }
  if (item.status === 'completed' && item.executed_at) {
    try {
      return new Intl.DateTimeFormat(undefined, {
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(new Date(item.executed_at));
    } catch {
      return displayTimelineStatus(item.status, t);
    }
  }
  return displayTimelineStatus(item.status, t);
};
</script>

<style lang="scss">
body > .tooltip.regua-action-tooltip,
body > .v-tooltip-container.regua-action-tooltip {
  max-width: 16rem;
  white-space: pre-line;
  text-align: left;
}
</style>
