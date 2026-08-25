<script>
import { useAlert } from 'dashboard/composables';
import ReportFilterSelector from './components/FilterSelector.vue';
import WorkflowMetrics from './components/WorkflowMetrics.vue';
import WorkflowEnrollmentsTable from './components/WorkflowEnrollmentsTable.vue';
import ReportsAPI from 'dashboard/api/reports';

export default {
  name: 'WorkflowReports',
  components: {
    ReportFilterSelector,
    WorkflowMetrics,
    WorkflowEnrollmentsTable,
  },
  data() {
    return {
      from: 0,
      to: 0,
      businessHours: false,
      workflowId: null,
      stepMetrics: [],
      enrollments: [],
      enrollmentsCount: 0,
      pageIndex: 1,
    };
  },
  computed: {
    requestPayload() {
      return {
        from: this.from,
        to: this.to,
      };
    },
    initialWorkflowId() {
      return this.$route.query.workflowId || this.workflowId;
    },
  },
  async mounted() {
    const queryId = this.$route.query.workflowId;
    if (queryId) {
      this.workflowId = Number(queryId) || queryId;
    }
  },
  methods: {
    fetchStepMetrics() {
      if (!this.from || !this.to) return;

      ReportsAPI.getWorkflowReports({
        from: this.from,
        to: this.to,
        workflowId: this.workflowId,
      })
        .then(response => {
          this.stepMetrics = response.data.steps || [];
        })
        .catch(() => {
          useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
        });
    },
    fetchEnrollments() {
      if (!this.from || !this.to) return;

      ReportsAPI.getWorkflowEnrollments({
        from: this.from,
        to: this.to,
        workflowId: this.workflowId,
        page: this.pageIndex,
      })
        .then(response => {
          this.enrollments = response.data.payload || [];
          this.enrollmentsCount = response.data.meta?.count || 0;
        })
        .catch(() => {
          useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
        });
    },
    fetchReportData() {
      this.fetchStepMetrics();
      this.fetchEnrollments();
    },
    onFilterChange({ from, to, businessHours }) {
      this.from = from;
      this.to = to;
      this.businessHours = businessHours;
      this.pageIndex = 1;
      this.fetchReportData();
    },
    onWorkflowChange(selectedWorkflow) {
      this.workflowId = selectedWorkflow?.id || null;
      this.pageIndex = 1;
      this.fetchReportData();
      this.$router.replace({
        query: {
          ...this.$route.query,
          workflowId: this.workflowId || undefined,
        },
      });
    },
    onPageNumberChange(pageIndex) {
      this.pageIndex = pageIndex;
      this.fetchEnrollments();
    },
  },
};
</script>

<template>
  <div class="flex-1 p-4 overflow-auto">
    <ReportFilterSelector
      :show-agents-filter="false"
      :show-group-by-filter="false"
      :show-business-hours-switch="false"
      show-workflow-filter
      :selected-workflow-id="initialWorkflowId"
      @filterChange="onFilterChange"
      @workflowFilterSelection="onWorkflowChange"
    />

    <WorkflowMetrics
      :filters="requestPayload"
      :workflow-id="workflowId"
    />

    <div
      class="grid grid-cols-1 p-2 mb-5 bg-white border rounded-md dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <div class="p-4">
        <h3 class="text-sm font-medium text-slate-700 dark:text-slate-200 mb-3">
          {{ $t('WORKFLOW_REPORTS.CHART.TITLE') }}
        </h3>
        <div
          v-if="stepMetrics.length"
          class="space-y-2"
        >
          <div
            v-for="step in stepMetrics"
            :key="step.node_id"
            class="flex items-center gap-3 text-sm"
          >
            <span class="flex-1 truncate text-slate-700 dark:text-slate-200">
              {{ step.label }}
            </span>
            <span class="text-slate-500 tabular-nums">
              {{ step.reply_rate }}%
            </span>
            <div class="w-32 h-2 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
              <div
                class="h-full bg-woot-500 rounded-full"
                :style="{ width: `${Math.min(step.reply_rate, 100)}%` }"
              />
            </div>
          </div>
        </div>
        <span
          v-else
          class="text-sm text-slate-600"
        >
          {{ $t('REPORT.NO_ENOUGH_DATA') }}
        </span>
      </div>
    </div>

    <h3 class="text-sm font-medium text-slate-700 dark:text-slate-200 mb-3">
      {{ $t('WORKFLOW_REPORTS.TABLE.TITLE') }}
    </h3>
    <WorkflowEnrollmentsTable
      :page-index="pageIndex"
      :enrollments="enrollments"
      :total-count="enrollmentsCount"
      @pageChange="onPageNumberChange"
    />
  </div>
</template>
