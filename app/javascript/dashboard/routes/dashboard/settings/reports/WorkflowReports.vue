<script>
import { useAlert } from 'dashboard/composables';
import ReportFilterSelector from './components/FilterSelector.vue';
import WorkflowMetrics from './components/WorkflowMetrics.vue';
import ReportsAPI from 'dashboard/api/reports';

export default {
  name: 'WorkflowReports',
  components: {
    ReportFilterSelector,
    WorkflowMetrics,
  },
  data() {
    return {
      from: 0,
      to: 0,
      businessHours: false,
      workflowId: null,
      workflows: [],
      stepMetrics: [],
    };
  },
  computed: {
    requestPayload() {
      return {
        from: this.from,
        to: this.to,
      };
    },
    chartCollection() {
      return {
        labels: this.stepMetrics.map(s => s.label),
        datasets: [
          {
            label: this.$t('WORKFLOW_REPORTS.CHART.REPLY_RATE'),
            data: this.stepMetrics.map(s => s.reply_rate),
          },
        ],
      };
    },
  },
  async mounted() {
    await this.fetchWorkflows();
    const queryId = this.$route.query.workflowId;
    if (queryId) {
      this.workflowId = Number(queryId) || queryId;
    }
  },
  methods: {
    async fetchWorkflows() {
      try {
        await this.$store.dispatch('workflows/get');
      } finally {
        this.workflows = this.$store.getters['workflows/getWorkflows'] || [];
      }
    },
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
    onFilterChange({ from, to, businessHours }) {
      this.from = from;
      this.to = to;
      this.businessHours = businessHours;
      this.fetchStepMetrics();
    },
    onWorkflowChange(event) {
      this.workflowId = event.target.value || null;
      this.fetchStepMetrics();
      this.$router.replace({
        query: {
          ...this.$route.query,
          workflowId: this.workflowId || undefined,
        },
      });
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
      @filterChange="onFilterChange"
    />

    <div class="mb-4">
      <label class="text-sm text-slate-600 dark:text-slate-300 mr-2">
        {{ $t('WORKFLOW_REPORTS.FILTER_WORKFLOW') }}
      </label>
      <select
        class="h-10 text-sm rounded-xl border border-slate-50 dark:border-slate-600 bg-slate-25 dark:bg-slate-900 px-3"
        :value="workflowId || ''"
        @change="onWorkflowChange"
      >
        <option value="">
          {{ $t('WORKFLOW_REPORTS.ALL_WORKFLOWS') }}
        </option>
        <option
          v-for="workflow in workflows"
          :key="workflow.id"
          :value="workflow.id"
        >
          {{ workflow.name }}
        </option>
      </select>
    </div>

    <WorkflowMetrics
      :filters="requestPayload"
      :workflow-id="workflowId"
    />

    <div
      class="grid grid-cols-1 p-2 bg-white border rounded-md dark:bg-slate-800 border-slate-100 dark:border-slate-700"
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
  </div>
</template>
