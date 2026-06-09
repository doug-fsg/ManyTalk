<script setup>
import { ref, watch, onMounted } from 'vue';
import ReportMetricCard from './ReportMetricCard.vue';
import ReportsAPI from 'dashboard/api/reports';

const props = defineProps({
  filters: {
    type: Object,
    required: true,
  },
  workflowId: {
    type: [Number, String],
    default: null,
  },
});

const activeCount = ref('0');
const completedCount = ref('0');
const replyRate = ref('0');
const cancelledCount = ref('0');

const formatToPercent = value => (value ? `${value}%` : '--');

const fetchMetrics = () => {
  if (!props.filters.to || !props.filters.from) return;

  ReportsAPI.getWorkflowReports({
    from: props.filters.from,
    to: props.filters.to,
    workflowId: props.workflowId,
  }).then(response => {
    const summary = response.data.summary || {};
    activeCount.value = (summary.active_count || 0).toLocaleString();
    completedCount.value = (summary.completed_count || 0).toLocaleString();
    replyRate.value = summary.reply_rate?.toString() || '0';
    cancelledCount.value = (summary.cancelled_count || 0).toLocaleString();
  });
};

watch(() => [props.filters, props.workflowId], fetchMetrics, { deep: true });
onMounted(fetchMetrics);
</script>

<template>
  <div
    class="flex flex-wrap mx-0 bg-white dark:bg-slate-800 rounded-[4px] p-4 mb-5 border border-solid border-slate-75 dark:border-slate-700"
  >
    <ReportMetricCard
      :label="$t('WORKFLOW_REPORTS.METRIC.ACTIVE.LABEL')"
      :info-text="$t('WORKFLOW_REPORTS.METRIC.ACTIVE.TOOLTIP')"
      :value="activeCount"
      class="flex-1"
    />
    <ReportMetricCard
      :label="$t('WORKFLOW_REPORTS.METRIC.COMPLETED.LABEL')"
      :info-text="$t('WORKFLOW_REPORTS.METRIC.COMPLETED.TOOLTIP')"
      :value="completedCount"
      class="flex-1"
    />
    <ReportMetricCard
      :label="$t('WORKFLOW_REPORTS.METRIC.REPLY_RATE.LABEL')"
      :info-text="$t('WORKFLOW_REPORTS.METRIC.REPLY_RATE.TOOLTIP')"
      :value="formatToPercent(replyRate)"
      class="flex-1"
    />
    <ReportMetricCard
      :label="$t('WORKFLOW_REPORTS.METRIC.CANCELLED.LABEL')"
      :info-text="$t('WORKFLOW_REPORTS.METRIC.CANCELLED.TOOLTIP')"
      :value="cancelledCount"
      class="flex-1"
    />
  </div>
</template>
