<script setup>
import { computed, watch, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { WORKFLOW_TRIGGER_EVENTS, WORKFLOW_ACTION_TYPES } from './constants';
import WorkflowConditionsEditor from './WorkflowConditionsEditor.vue';

const props = defineProps({
  node: { type: Object, default: null },
  graphSettings: { type: Object, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update-node', 'update-settings']);
const { t } = useI18n();

const localSettings = ref({ ...props.graphSettings });
watch(
  () => props.graphSettings,
  val => { localSettings.value = { ...(val || {}) }; },
  { deep: true }
);

const nodeType = computed(() => {
  const node = props.node;
  return node && node.properties && node.properties.workflowNodeType;
});
const nodeProps = computed(() => {
  const node = props.node;
  return (node && node.properties) || {};
});

const updateProp = (key, value) => emit('update-node', { [key]: value });

const onConditionsUpdate = conditions => updateProp('conditions', conditions);

const onTriggerEventChange = event => {
  emit('update-node', { event_name: event, conditions: [] });
};
const updateSettings = (key, value) => {
  localSettings.value = { ...localSettings.value, [key]: value };
  emit('update-settings', localSettings.value);
};

const NODE_META_BASE = {
  trigger: { color: '#2563EB', icon: 'M13 10V3L4 14h7v7l9-11h-7z', labelKey: 'WORKFLOW.EDITOR.NODE_TRIGGER' },
  wait: { color: '#7C3AED', icon: 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z', labelKey: 'WORKFLOW.EDITOR.NODE_WAIT' },
  condition: {
    color: '#D97706',
    icon: 'M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
    labelKey: 'WORKFLOW.EDITOR.NODE_CONDITION',
  },
  action: { color: '#059669', icon: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z', labelKey: 'WORKFLOW.EDITOR.NODE_ACTION' },
};

const currentMeta = computed(() => {
  const base = NODE_META_BASE[nodeType.value];
  if (!base) return null;
  return { ...base, label: t(base.labelKey) };
});

const inputClass =
  'w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500/30 disabled:opacity-50';
const labelClass =
  'block text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider mb-1.5';
</script>

<template>
    <div
      class="w-full max-w-md shrink-0 flex flex-col bg-white dark:bg-slate-900 border-l border-slate-200 dark:border-slate-700 overflow-hidden min-w-0 sm:min-w-[22rem] sm:w-96"
    >
    <div class="px-4 py-3 border-b border-slate-200 dark:border-slate-700">
      <template v-if="node && currentMeta">
        <div class="flex items-center gap-2.5">
          <span
            class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
            :style="{ background: currentMeta.color }"
          >
            <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" :d="currentMeta.icon" />
            </svg>
          </span>
          <div>
            <p class="text-sm font-semibold text-slate-900 dark:text-slate-50">{{ currentMeta.label }}</p>
            <p class="text-xs text-slate-500 dark:text-slate-400">{{ $t('WORKFLOW.EDITOR.NODE_SETTINGS') }}</p>
          </div>
        </div>
      </template>
      <template v-else>
        <p class="text-sm font-semibold text-slate-900 dark:text-slate-50">
          {{ $t('WORKFLOW.EDITOR.FLOW_SETTINGS') }}
        </p>
      </template>
    </div>

    <div class="flex-1 overflow-y-auto p-4 space-y-5 min-w-0">
      <template v-if="!node">
        <div class="space-y-3">
          <p class="text-xs text-slate-500 dark:text-slate-400">{{ $t('WORKFLOW.EDITOR.CANCEL_SECTION') }}</p>

          <label class="flex items-start gap-3 cursor-pointer">
            <input
              type="checkbox"
              :checked="localSettings.cancel_on_contact_reply !== false"
              :disabled="readOnly"
              class="mt-1"
              @change="updateSettings('cancel_on_contact_reply', $event.target.checked)"
            />
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ $t('WORKFLOW.EDITOR.CANCEL_ON_REPLY') }}
            </span>
          </label>

          <label class="flex items-start gap-3 cursor-pointer">
            <input
              type="checkbox"
              :checked="localSettings.cancel_on_conversation_resolved !== false"
              :disabled="readOnly"
              class="mt-1"
              @change="updateSettings('cancel_on_conversation_resolved', $event.target.checked)"
            />
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ $t('WORKFLOW.EDITOR.CANCEL_ON_RESOLVED') }}
            </span>
          </label>
        </div>

        <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('WORKFLOW.EDITOR.SELECT_NODE_HINT') }}
          </p>
        </div>
      </template>

      <template v-if="nodeType === 'trigger'">
        <div>
          <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.EVENT') }}</label>
          <select
            :value="nodeProps.event_name"
            :disabled="readOnly"
            :class="inputClass"
            @change="onTriggerEventChange($event.target.value)"
          >
            <option v-for="ev in WORKFLOW_TRIGGER_EVENTS" :key="ev.key" :value="ev.key">
              {{ ev.value }}
            </option>
          </select>
        </div>
        <WorkflowConditionsEditor
          :conditions="nodeProps.conditions || []"
          :event-name="nodeProps.event_name"
          :read-only="readOnly"
          @update:conditions="onConditionsUpdate"
        />
      </template>

      <template v-if="nodeType === 'wait'">
        <div>
          <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.DURATION') }}</label>
          <div class="flex gap-2">
            <input
              type="number"
              min="1"
              :value="nodeProps.duration"
              :disabled="readOnly"
              :class="inputClass"
              @input="updateProp('duration', Number($event.target.value))"
            />
            <select
              :value="nodeProps.unit"
              :disabled="readOnly"
              :class="inputClass"
              @change="updateProp('unit', $event.target.value)"
            >
              <option value="minutes">{{ $t('WORKFLOW.EDITOR.MINUTES') }}</option>
              <option value="hours">{{ $t('WORKFLOW.EDITOR.HOURS') }}</option>
              <option value="days">{{ $t('WORKFLOW.EDITOR.DAYS') }}</option>
            </select>
          </div>
        </div>
        <p class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('WORKFLOW.EDITOR.WAIT_HINT') }}
        </p>
      </template>

      <template v-if="nodeType === 'action'">
        <div>
          <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.ACTION') }}</label>
          <select
            :value="nodeProps.action_name"
            :disabled="readOnly"
            :class="inputClass"
            @change="updateProp('action_name', $event.target.value)"
          >
            <option v-for="action in WORKFLOW_ACTION_TYPES" :key="action.key" :value="action.key">
              {{ action.label }}
            </option>
          </select>
        </div>
        <div
          v-if="nodeProps.action_name === 'send_message' || nodeProps.action_name === 'add_private_note'"
        >
          <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.MESSAGE_LABEL') }}</label>
          <textarea
            :value="(nodeProps.action_params && nodeProps.action_params[0]) || ''"
            :disabled="readOnly"
            :class="inputClass + ' min-h-[100px]'"
            :placeholder="$t('WORKFLOW.EDITOR.MESSAGE_PLACEHOLDER')"
            @input="updateProp('action_params', [$event.target.value])"
          />
        </div>
        <div v-else-if="nodeProps.action_name === 'send_webhook_event'">
          <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.WEBHOOK_LABEL') }}</label>
          <input
            type="url"
            :value="(nodeProps.action_params && nodeProps.action_params[0]) || ''"
            :disabled="readOnly"
            :class="inputClass"
            placeholder="https://"
            @input="updateProp('action_params', [$event.target.value])"
          />
        </div>
      </template>

      <template v-if="nodeType === 'condition'">
        <WorkflowConditionsEditor
          :conditions="nodeProps.conditions || []"
          :read-only="readOnly"
          @update:conditions="onConditionsUpdate"
        />
        <div class="space-y-2">
          <div class="flex items-center gap-2 p-2 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800">
            <div class="w-2 h-2 rounded-full bg-green-500 flex-shrink-0" />
            <p class="text-xs text-green-700 dark:text-green-300">{{ $t('WORKFLOW.EDITOR.BRANCH_YES') }}</p>
          </div>
          <div class="flex items-center gap-2 p-2 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800">
            <div class="w-2 h-2 rounded-full bg-red-500 flex-shrink-0" />
            <p class="text-xs text-red-700 dark:text-red-300">{{ $t('WORKFLOW.EDITOR.BRANCH_NO') }}</p>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
