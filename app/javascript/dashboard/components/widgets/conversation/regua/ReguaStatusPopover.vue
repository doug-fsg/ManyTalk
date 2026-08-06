<template>
  <div
    class="absolute flex flex-col items-start bg-white dark:bg-slate-800 z-50 px-4 py-3 border border-solid border-ash-200 dark:border-slate-700 w-[20rem] rounded-xl gap-3 shadow-lg"
  >
    <ReguaPanelStatus
      :status="status"
      :workflow-name="workflowName"
      :current-node-label="currentNodeLabel"
      :current-node-type="currentNodeType"
      :next-scheduled-at="nextScheduledAt"
      :reply-watch="replyWatch"
    />
    <p class="text-xs text-ash-800 dark:text-slate-400">
      {{ $t('WORKFLOW.REGUA.POPOVER_HINT') }}
    </p>
  </div>
</template>

<script setup>
import ReguaPanelStatus from './ReguaPanelStatus.vue';

defineProps({
  status: { type: String, default: '' },
  workflowName: { type: String, default: '' },
  currentNodeLabel: { type: String, default: '' },
  currentNodeType: { type: String, default: '' },
  nextScheduledAt: { type: String, default: null },
  replyWatch: { type: Object, default: null },
});
</script>
