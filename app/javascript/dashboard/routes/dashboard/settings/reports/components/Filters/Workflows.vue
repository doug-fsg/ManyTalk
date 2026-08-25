<script>
import { mapGetters } from 'vuex';

export default {
  name: 'ReportsFiltersWorkflows',
  props: {
    selectedWorkflowId: {
      type: [Number, String],
      default: null,
    },
  },
  data() {
    return {
      selectedOption: null,
    };
  },
  computed: {
    ...mapGetters({
      workflows: 'workflows/getWorkflows',
    }),
    options() {
      return this.workflows;
    },
  },
  watch: {
    selectedWorkflowId: 'syncSelectedOption',
    workflows: 'syncSelectedOption',
  },
  async mounted() {
    await this.$store.dispatch('workflows/get');
    this.syncSelectedOption();
  },
  methods: {
    syncSelectedOption() {
      if (!this.selectedWorkflowId) {
        return;
      }
      const match = this.options.find(
        workflow => Number(workflow.id) === Number(this.selectedWorkflowId)
      );
      if (match && this.selectedOption?.id !== match.id) {
        this.selectedOption = match;
        this.handleInput();
      }
    },
    handleInput() {
      this.$emit('workflowFilterSelection', this.selectedOption);
    },
  },
};
</script>

<template>
  <div class="multiselect-wrap--small">
    <multiselect
      v-model="selectedOption"
      class="no-margin"
      :placeholder="$t('WORKFLOW_REPORTS.FILTER_WORKFLOW')"
      label="name"
      track-by="id"
      :options="options"
      :option-height="24"
      :show-labels="false"
      :allow-empty="true"
      @input="handleInput"
    />
  </div>
</template>
