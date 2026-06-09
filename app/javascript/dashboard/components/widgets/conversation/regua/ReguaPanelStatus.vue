<template>
  <div aria-live="polite" class="space-y-2">
    <div class="flex items-center gap-2">
      <span
        class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
        :class="statusClass"
      >
        {{ statusLabel }}
      </span>
    </div>
    <p
      class="text-sm text-slate-600 dark:text-slate-300 truncate min-w-0"
      :title="workflowName"
    >
      <span class="font-medium text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.REGUA.WORKFLOW_LABEL') }}:
      </span>
      {{ workflowName }}
    </p>
    <p
      v-if="currentNodeLabel"
      class="text-sm text-slate-600 dark:text-slate-300"
    >
      <span class="font-medium text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.REGUA.STAGE_LABEL') }}:
      </span>
      {{ currentNodeLabel }}
    </p>
    <p
      v-if="replyDeadlineAt"
      class="text-sm text-slate-600 dark:text-slate-300 tabular-nums"
    >
      <span class="font-medium text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.REGUA.REPLY_DEADLINE_AT') }}:
      </span>
      {{ formattedReplyDeadline }}
    </p>
    <p
      v-else-if="nextScheduledAt"
      class="text-sm text-slate-600 dark:text-slate-300 tabular-nums"
    >
      <span class="font-medium text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.REGUA.NEXT_AT') }}:
      </span>
      {{ formattedDate }}
    </p>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  status: { type: String, default: '' },
  workflowName: { type: String, default: '' },
  currentNodeLabel: { type: String, default: '' },
  nextScheduledAt: { type: String, default: null },
  replyWatch: { type: Object, default: null },
});

const { t } = useI18n();

const STATUS_MAP = {
  waiting: {
    key: 'STATUS_WAITING',
    class:
      'bg-violet-100 text-violet-800 dark:bg-violet-900/30 dark:text-violet-300',
  },
  active: {
    key: 'STATUS_ACTIVE',
    class:
      'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300',
  },
  paused: {
    key: 'STATUS_PAUSED',
    class:
      'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300',
  },
  completed: {
    key: 'STATUS_COMPLETED',
    class: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
  },
  cancelled: {
    key: 'STATUS_CANCELLED',
    class: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
  },
};

const statusConfig = computed(
  () => STATUS_MAP[props.status] || STATUS_MAP.active
);
const statusLabel = computed(
  () => t(`WORKFLOW.REGUA.${statusConfig.value.key}`)
);
const statusClass = computed(() => statusConfig.value.class);

const replyDeadlineAt = computed(() => props.replyWatch?.deadline_at || null);

const formattedReplyDeadline = computed(() => {
  if (!replyDeadlineAt.value) return '';
  try {
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(replyDeadlineAt.value));
  } catch {
    return replyDeadlineAt.value;
  }
});

const formattedDate = computed(() => {
  if (!props.nextScheduledAt) return '';
  try {
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(props.nextScheduledAt));
  } catch {
    return props.nextScheduledAt;
  }
});
</script>
