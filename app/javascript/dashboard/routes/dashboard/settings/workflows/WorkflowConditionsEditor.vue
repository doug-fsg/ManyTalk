<script>
import { mapGetters } from 'vuex';
import debounce from 'lodash/debounce';
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
  isACustomAttribute,
} from 'dashboard/helper/automationHelper';
import { OPERATOR_TYPES_1 } from '../automation/operators';
import { serializeWorkflowConditions } from 'dashboard/helper/workflowConditionHelper';
import {
  getWorkflowAutomationTypes,
  WORKFLOW_FLOW_EVENT_KEY,
  WORKFLOW_REPLY_CONDITION_KEYS,
} from './constants';
import { ensureWorkflowEditorBootstrapped } from './useWorkflowEditorBootstrap';

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
      automationTypes: getWorkflowAutomationTypes(),
      allCustomAttributes: [],
      localConditions: [],
      mode: 'edit',
      isReady: false,
      isEmitting: false,
      lastSyncedConditionsKey: '',
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
    replyBooleanOptions() {
      return [
        { id: true, name: this.$t('WORKFLOW.EDITOR.CONDITION_YES') },
        { id: false, name: this.$t('WORKFLOW.EDITOR.CONDITION_NO') },
      ];
    },
  },
  watch: {
    conditions: {
      handler(nextConditions) {
        if (!this.isReady || this.isEmitting) return;
        const key = JSON.stringify(nextConditions || []);
        if (key === this.lastSyncedConditionsKey) return;
        this.syncLocalFromProps();
      },
    },
    eventName(newVal, oldVal) {
      if (!this.isReady || !newVal || newVal === oldVal || this.eventName === null) return;
      if (newVal === 'manual' || newVal === 'contact_kanban_stage_changed') {
        this.localConditions = [];
      } else {
        this.localConditions = JSON.parse(
          JSON.stringify(getDefaultConditions(newVal))
        );
      }
      this.emitConditions();
    },
  },
  created() {
    this.debouncedEmitConditions = debounce(this.emitConditionsNow, 250);
  },
  beforeUnmount() {
    if (this.debouncedEmitConditions?.cancel) {
      this.debouncedEmitConditions.cancel();
    }
  },
  async mounted() {
    await ensureWorkflowEditorBootstrapped(this.$store);
    this.allCustomAttributes = this.$store.getters['attributes/getAttributes'];
    this.ensureAutomationTypesExtended();
    this.syncLocalFromProps();
    this.isReady = true;
  },
  methods: {
    ensureAutomationTypesExtended() {
      if (this.automationTypes._flowCatalogExtended) return;
      this.manifestCustomAttributes(this.automationTypes);
      this.addCustomAttributesToFlowEvent();
      this.addKanbanAttributesToFlowEvent();
      this.automationTypes._flowCatalogExtended = true;
    },
    findCustomAttribute(key) {
      return isACustomAttribute(this.allCustomAttributes, key);
    },
    isReplyConditionKey(key) {
      return WORKFLOW_REPLY_CONDITION_KEYS.includes(key);
    },
    addKanbanAttributesToFlowEvent() {
      const kanbanRaw = (this.allCustomAttributes || []).filter(
        attr =>
          attr.attribute_model === 'contact_attribute' && attr.is_kanban === true
      );
      if (!kanbanRaw.length) return;

      const flowConditions = this.automationTypes[WORKFLOW_FLOW_EVENT_KEY].conditions;
      const existingKeys = new Set(flowConditions.map(c => c.key));
      const kanbanEntries = [];

      if (!existingKeys.has('workflow_kanban_header')) {
        kanbanEntries.push({
          key: 'workflow_kanban_header',
          name: this.$t('CONTACT_PANEL.KANBAN_STAGE') || 'Etapa do Kanban',
          disabled: true,
        });
      }

      kanbanRaw.forEach(attr => {
        if (existingKeys.has(attr.attribute_key)) return;
        kanbanEntries.push({
          key: attr.attribute_key,
          name: attr.attribute_display_name,
          inputType: 'kanban_stage_select',
          filterOperators: OPERATOR_TYPES_1,
          customAttributeType: 'contact_attribute',
        });
      });

      flowConditions.push(...kanbanEntries);
    },
    addCustomAttributesToFlowEvent() {
      const conversationRaw = this.$store.getters['attributes/getAttributesByModel'](
        'conversation_attribute'
      );
      const contactRaw = this.$store.getters['attributes/getAttributesByModel'](
        'contact_attribute'
      ).filter(attr => !attr.is_kanban);
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
      this.lastSyncedConditionsKey = JSON.stringify(base);
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
      this.localConditions = formatted.conditions.map(condition => {
        if (!this.isReplyConditionKey(condition.attribute_key)) return condition;
        if (condition.filter_operator === 'is_present') {
          return {
            ...condition,
            filter_operator: 'equal_to',
            values: this.replyBooleanOptions.filter(o => o.id === true),
          };
        }
        if (
          condition.values === '' ||
          condition.values == null ||
          (Array.isArray(condition.values) && condition.values.length === 0)
        ) {
          return {
            ...condition,
            filter_operator: 'equal_to',
            values: this.replyBooleanOptions.filter(o => o.id === true),
          };
        }
        return condition;
      });
    },
    emitConditionsNow() {
      this.isEmitting = true;
      const payload = serializeWorkflowConditions(this.localConditions, {
        dropEmpty: false,
      });
      this.lastSyncedConditionsKey = JSON.stringify(payload);
      this.$emit('update:conditions', payload);
      this.$nextTick(() => {
        this.isEmitting = false;
      });
    },
    emitConditions() {
      this.debouncedEmitConditions();
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
    getInputTypeForCondition(condition) {
      if (!condition) return 'plain_text';
      const key = condition.attribute_key;
      const op = condition.filter_operator;
      if (key === 'created_at' || key === 'last_activity_at') {
        if (op === 'days_before' || op === 'months_before') return 'plain_text';
      }
      const customAttribute = this.findCustomAttribute(key);
      if (customAttribute && customAttribute.is_kanban) return 'kanban_stage_select';
      if (this.isReplyConditionKey(key)) return 'search_select';
      return getInputType(
        this.allCustomAttributes,
        this.automationTypes,
        this.automationStub,
        key
      );
    },
    getReplyBooleanOptions() {
      return this.replyBooleanOptions;
    },
    getDropdownValuesForCondition(condition) {
      if (!condition) return [];
      const key = condition.attribute_key;
      if (this.isReplyConditionKey(key)) return this.replyBooleanOptions;
      const customAttribute = this.findCustomAttribute(key);
      if (customAttribute && customAttribute.is_kanban) {
        return (customAttribute.attribute_values || []).map(stage => ({
          id: stage,
          name: stage,
        }));
      }
      return this.getConditionDropdownValues(key);
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
          :input-type="getInputTypeForCondition(localConditions[i])"
          :operators="getOperatorsForKey(localConditions[i].attribute_key)"
          :dropdown-values="getDropdownValuesForCondition(localConditions[i])"
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
