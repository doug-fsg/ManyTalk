<script>
import { mapGetters } from 'vuex';
import FilterInputBox from 'dashboard/components/widgets/FilterInput/Index.vue';
import { useAutomation } from 'dashboard/composables/useAutomation';
import {
  getAttributes,
  getInputType,
  getOperators,
  getCustomAttributeType,
  getDefaultConditions,
  generateCustomAttributeTypes,
  generateCustomAttributes,
} from 'dashboard/helper/automationHelper';
import { serializeWorkflowConditions } from 'dashboard/helper/workflowConditionHelper';
import {
  buildWorkflowAutomationTypes,
  WORKFLOW_FLOW_EVENT_KEY,
} from './constants';

export default {
  name: 'WorkflowConditionsEditor',
  components: { FilterInputBox },
  props: {
    conditions: { type: Array, default: () => [] },
    /** Trigger event name; omit for mid-flow condition node catalog. */
    eventName: { type: String, default: null },
    readOnly: { type: Boolean, default: false },
  },
  setup() {
    const {
      getConditionDropdownValues,
      removeFilter,
      resetFilter,
      formatAutomation,
      manifestCustomAttributes,
    } = useAutomation();
    return {
      getConditionDropdownValues,
      removeFilter,
      resetFilter,
      formatAutomation,
      manifestCustomAttributes,
    };
  },
  data() {
    return {
      automationTypes: buildWorkflowAutomationTypes(),
      allCustomAttributes: [],
      localConditions: [],
      mode: 'edit',
      isReady: false,
      isEmitting: false,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
    }),
    contextEvent() {
      return this.eventName || WORKFLOW_FLOW_EVENT_KEY;
    },
    automationStub() {
      return { event_name: this.contextEvent };
    },
    filterAttributesForContext() {
      return getAttributes(this.automationTypes, this.contextEvent);
    },
  },
  watch: {
    conditions: {
      deep: true,
      handler() {
        if (!this.isReady || this.isEmitting) return;
        this.syncLocalFromProps();
      },
    },
    eventName(newVal, oldVal) {
      if (!this.isReady || !newVal || newVal === oldVal || this.eventName === null) return;
      this.localConditions = JSON.parse(JSON.stringify(getDefaultConditions(newVal)));
      this.emitConditions();
    },
  },
  async mounted() {
    await Promise.all([
      this.$store.dispatch('inboxes/get'),
      this.$store.dispatch('agents/get'),
      this.$store.dispatch('contacts/get'),
      this.$store.dispatch('teams/get'),
      this.$store.dispatch('labels/get'),
      this.$store.dispatch('campaigns/get'),
    ]);
    this.allCustomAttributes = this.$store.getters['attributes/getAttributes'];
    this.manifestCustomAttributes(this.automationTypes);
    this.addCustomAttributesToFlowEvent();
    this.syncLocalFromProps();
    this.isReady = true;
  },
  methods: {
    addCustomAttributesToFlowEvent() {
      const conversationRaw = this.$store.getters['attributes/getAttributesByModel'](
        'conversation_attribute'
      );
      const contactRaw = this.$store.getters['attributes/getAttributesByModel'](
        'contact_attribute'
      );
      const conversationTypes = generateCustomAttributeTypes(
        conversationRaw,
        'conversation_attribute'
      );
      const contactTypes = generateCustomAttributeTypes(contactRaw, 'contact_attribute');
      const extras = generateCustomAttributes(
        conversationTypes,
        contactTypes,
        this.$t('AUTOMATION.CONDITION.CONVERSATION_CUSTOM_ATTR_LABEL'),
        this.$t('AUTOMATION.CONDITION.CONTACT_CUSTOM_ATTR_LABEL')
      );
      this.automationTypes[WORKFLOW_FLOW_EVENT_KEY].conditions.push(...extras);
    },
    syncLocalFromProps() {
      const base = Array.isArray(this.conditions) ? this.conditions : [];
      if (base.length === 0) {
        this.localConditions = [];
        return;
      }
      const formatted = this.formatAutomation(
        {
          event_name: this.contextEvent,
          conditions: base,
          actions: [],
        },
        this.allCustomAttributes,
        this.automationTypes,
        []
      );
      this.localConditions = formatted.conditions;
    },
    emitConditions() {
      this.isEmitting = true;
      const payload = serializeWorkflowConditions(this.localConditions, {
        dropEmpty: false,
      });
      this.$emit('update:conditions', payload);
      this.$nextTick(() => {
        this.isEmitting = false;
      });
    },
    onConditionInput() {
      this.emitConditions();
    },
    appendCondition() {
      const seedEvent =
        this.contextEvent === WORKFLOW_FLOW_EVENT_KEY
          ? 'conversation_created'
          : this.contextEvent;
      const next = JSON.parse(JSON.stringify(getDefaultConditions(seedEvent)));
      this.localConditions = this.localConditions.concat(next);
      this.emitConditions();
    },
    onRemoveFilter(index) {
      const stub = { conditions: this.localConditions, event_name: this.contextEvent };
      this.removeFilter(stub, index);
      this.localConditions = stub.conditions;
      this.emitConditions();
    },
    onResetFilter(index) {
      const stub = { conditions: this.localConditions, event_name: this.contextEvent };
      this.resetFilter(
        stub,
        this.automationTypes,
        index,
        this.localConditions[index]
      );
      this.localConditions = stub.conditions;
      this.emitConditions();
    },
    getInputTypeForKey(key) {
      return getInputType(
        this.allCustomAttributes,
        this.automationTypes,
        this.automationStub,
        key
      );
    },
    getOperatorsForKey(key) {
      return getOperators(
        this.allCustomAttributes,
        this.automationTypes,
        this.automationStub,
        this.mode,
        key
      );
    },
    getCustomAttributeTypeForKey(key) {
      return getCustomAttributeType(this.automationTypes, this.automationStub, key);
    },
  },
};
</script>

<template>
  <section class="space-y-3">
    <label class="block text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
      {{ $t('AUTOMATION.ADD.FORM.CONDITIONS.LABEL') }}
    </label>
    <div
      class="w-full min-w-0 p-3 rounded-xl border border-slate-200 dark:border-slate-600 bg-slate-50/90 dark:bg-slate-800/60 space-y-3"
    >
      <div
        v-for="(condition, i) in localConditions"
        :key="'wf-cond-wrap-' + i + '-' + (condition.attribute_key || '')"
        class="rounded-lg border border-slate-200/80 dark:border-slate-600/80 bg-white dark:bg-slate-900/80 p-1 shadow-sm"
      >
        <FilterInputBox
          v-model="localConditions[i]"
          layout="stacked"
          :filter-attributes="filterAttributesForContext"
          :input-type="getInputTypeForKey(localConditions[i].attribute_key)"
          :operators="getOperatorsForKey(localConditions[i].attribute_key)"
          :dropdown-values="getConditionDropdownValues(localConditions[i].attribute_key)"
          :show-query-operator="i !== localConditions.length - 1"
          :custom-attribute-type="getCustomAttributeTypeForKey(localConditions[i].attribute_key)"
          :disabled="readOnly"
          @input="onConditionInput"
          @resetFilter="onResetFilter(i)"
          @removeFilter="onRemoveFilter(i)"
        />
      </div>
      <button
        v-if="!readOnly"
        type="button"
        class="mt-1 w-full py-2.5 text-xs font-semibold text-woot-600 dark:text-woot-400 bg-white dark:bg-slate-900 border border-dashed border-woot-300 dark:border-woot-600 rounded-lg hover:bg-woot-50 dark:hover:bg-slate-800 transition-colors cursor-pointer"
        @click="appendCondition"
      >
        + {{ $t('WORKFLOW.EDITOR.ADD_CONDITION') }}
      </button>
    </div>
    <p v-if="eventName === null" class="text-xs text-slate-500 dark:text-slate-400">
      {{ $t('WORKFLOW.EDITOR.FLOW_CONDITION_HINT') }}
    </p>
  </section>
</template>
