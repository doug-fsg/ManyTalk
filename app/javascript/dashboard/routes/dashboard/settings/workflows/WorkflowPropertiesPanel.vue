<script setup>
import { computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'dashboard/composables/useI18n';
import { WORKFLOW_WAIT_RESPONDERS } from './constants';
import {
  WORKFLOW_TRIGGER_EVENTS_EXTENDED,
  FORM_SUBMITTED_EVENT_KEY,
  extractFormIdsFromConditions,
  buildFormSubmittedConditions,
} from './workflowExtensions';
import WorkflowConditionsEditor from './WorkflowConditionsEditor.vue';
import WorkflowAiOutreachPanel from './WorkflowAiOutreachPanel.vue';
import WorkflowAiAnalysisPanel from './WorkflowAiAnalysisPanel.vue';
import WorkflowAiWaitForIntentPanel from './WorkflowAiWaitForIntentPanel.vue';
import WorkflowActionList from './WorkflowActionList.vue';

const props = defineProps({
  node: { type: Object, default: null },
  readOnly: { type: Boolean, default: false },
  nodeErrors: { type: Array, default: () => [] },
  asModal: { type: Boolean, default: false },
});

const emit = defineEmits(['update-node']);
const { t } = useI18n();
const store = useStore();

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);
const publishedForms = computed(() => {
  const forms = store.getters['accountForms/getAccountForms'] || [];
  return forms.filter(form => form.status === 'published');
});

const selectedFormIds = computed(() =>
  extractFormIdsFromConditions(nodeProps.value.conditions || [])
);

const isFormSubmittedTrigger = computed(
  () => nodeProps.value.event_name === FORM_SUBMITTED_EVENT_KEY
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
  const patch = { event_name: event, conditions: [] };
  if (event !== FORM_SUBMITTED_EVENT_KEY) {
    patch.inbox_id = '';
  }
  emit('update-node', patch);
};

const onFormTriggerInboxChange = value => {
  updateProp('inbox_id', value ? String(value) : '');
};

const isFormSelected = formId => selectedFormIds.value.includes(String(formId));

const toggleForm = formId => {
  if (props.readOnly) return;
  const ids = [...selectedFormIds.value];
  const strId = String(formId);
  const idx = ids.indexOf(strId);
  if (idx === -1) ids.push(strId);
  else ids.splice(idx, 1);
  updateProp('conditions', buildFormSubmittedConditions(ids));
};

const NODE_META_BASE = {
  trigger: { color: '#2563EB', icon: 'M13 10V3L4 14h7v7l9-11h-7z', labelKey: 'WORKFLOW.EDITOR.NODE_TRIGGER' },
  wait: { color: '#7C3AED', icon: 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z', labelKey: 'WORKFLOW.EDITOR.NODE_WAIT' },
  wait_for_reply: {
    color: '#0D9488',
    icon: 'M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z',
    labelKey: 'WORKFLOW.EDITOR.NODE_WAIT_FOR_REPLY',
  },
  condition: {
    color: '#D97706',
    icon: 'M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
    labelKey: 'WORKFLOW.EDITOR.NODE_CONDITION',
  },
  action: { color: '#059669', icon: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z', labelKey: 'WORKFLOW.EDITOR.NODE_ACTION' },
  ai_outreach: {
    color: '#7C3AED',
    icon:
      'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.847a4.5 4.5 0 003.09 3.09L15.75 12l-2.847.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z',
    labelKey: 'WORKFLOW.EDITOR.NODE_CALL_CLIENT',
  },
  ai_conversation_analysis: {
    color: '#7C3AED',
    icon:
      'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.847a4.5 4.5 0 003.09 3.09L15.75 12l-2.847.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z',
    labelKey: 'WORKFLOW.EDITOR.NODE_CONVERSATION_ANALYSIS',
  },
  ai_wait_for_intent: {
    color: '#7C3AED',
    icon: 'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.847a4.5 4.5 0 003.09 3.09L15.75 12l-2.847.813a4.5 4.5 0 00-3.09 3.09zM12 8v4l3 3',
    labelKey: 'WORKFLOW.EDITOR.NODE_AI_WAIT_FOR_INTENT',
  },
};

const currentMeta = computed(() => NODE_META_BASE[nodeType.value] || null);

const stepLabelPlaceholder = computed(() => {
  const meta = NODE_META_BASE[nodeType.value];
  return meta ? t(meta.labelKey) : t('WORKFLOW.EDITOR.STEP_LABEL_PLACEHOLDER');
});

const workflowStepLabelInputId = 'workflow-node-step-label';

const inputClass =
  'w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-500/30 disabled:opacity-50';
const labelClass =
  'block text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider mb-1.5';
const stepLabelTitleClass =
  'reset-base w-full m-0 h-auto px-2 py-1 rounded-lg text-sm font-medium text-slate-700 dark:text-slate-200 bg-transparent border-0 placeholder:text-slate-400 dark:placeholder:text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700 focus-visible:outline-none focus-visible:bg-slate-50 dark:focus-visible:bg-slate-700 focus-visible:ring-2 focus-visible:ring-woot-500 transition-colors duration-200 ease-smooth disabled:opacity-50';
</script>

<template>
  <div
    class="flex flex-col min-w-0"
    :class="
      asModal
        ? 'w-full'
        : 'w-full max-w-md shrink-0 bg-white dark:bg-slate-900 border-l border-slate-50 dark:border-slate-800/50 overflow-hidden sm:min-w-[22rem] sm:w-96'
    "
  >
    <div
      v-if="!asModal"
      class="px-3 py-2.5 border-b border-slate-50 dark:border-slate-800/50"
    >
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
          <div class="min-w-0 flex-1">
            <label :for="workflowStepLabelInputId" class="sr-only">
              {{ stepLabelPlaceholder }}
            </label>
            <input
              :id="workflowStepLabelInputId"
              type="text"
              :value="nodeProps.label || ''"
              :disabled="readOnly"
              :class="stepLabelTitleClass"
              :placeholder="stepLabelPlaceholder"
              autocomplete="off"
              spellcheck="false"
              :title="t('WORKFLOW.EDITOR.STEP_LABEL_HINT')"
              @input="updateProp('label', $event.target.value)"
            />
          </div>
        </div>
      </template>
      <template v-else>
        <p class="text-sm font-semibold text-slate-900 dark:text-slate-50">
          {{ $t('WORKFLOW.EDITOR.NODE_SETTINGS') }}
        </p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
          {{ $t('WORKFLOW.EDITOR.SELECT_NODE_HINT') }}
        </p>
      </template>
    </div>

    <div
      v-if="node && nodeType"
      class="space-y-5 min-w-0"
      :class="asModal ? 'pb-2' : 'flex-1 overflow-y-auto p-4'"
    >
      <div
        v-if="nodeErrors.length"
        class="flex items-start gap-2 text-xs text-amber-800/90 dark:text-amber-300/90"
        role="status"
      >
        <fluent-icon
          icon="warning"
          size="14"
          class="flex-shrink-0 mt-0.5 text-amber-600 dark:text-amber-400"
          aria-hidden="true"
        />
        <ul class="space-y-0.5 min-w-0">
          <li v-for="(message, index) in nodeErrors" :key="index">
            {{ message }}
          </li>
        </ul>
      </div>

      <template v-if="nodeType === 'trigger'">
        <div>
          <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.EVENT') }}</label>
          <select
            :value="nodeProps.event_name"
            :disabled="readOnly"
            :class="inputClass"
            @change="onTriggerEventChange($event.target.value)"
          >
            <option v-for="ev in WORKFLOW_TRIGGER_EVENTS_EXTENDED" :key="ev.key" :value="ev.key">
              {{ ev.value }}
            </option>
          </select>
        </div>
        <div v-if="isFormSubmittedTrigger" class="space-y-4">
          <div>
            <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.FORM_TRIGGER_FORMS_LABEL') }}</label>
            <p
              v-if="!publishedForms.length"
              class="text-xs text-slate-500 dark:text-slate-400"
            >
              {{ $t('WORKFLOW.EDITOR.FORM_TRIGGER_FORMS_EMPTY') }}
            </p>
            <div
              v-else
              class="max-h-40 overflow-y-auto rounded-lg border border-slate-200 dark:border-slate-600 divide-y divide-slate-100 dark:divide-slate-700"
            >
              <label
                v-for="form in publishedForms"
                :key="form.id"
                class="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800/60"
                :class="readOnly ? 'opacity-60 cursor-not-allowed' : ''"
              >
                <input
                  type="checkbox"
                  class="rounded border-slate-300 dark:border-slate-600"
                  :checked="isFormSelected(form.id)"
                  :disabled="readOnly"
                  @change="toggleForm(form.id)"
                />
                <span class="min-w-0 truncate text-slate-800 dark:text-slate-100">{{ form.name }}</span>
              </label>
            </div>
            <p class="mt-1.5 text-xs text-slate-500 dark:text-slate-400">
              {{ $t('WORKFLOW.EDITOR.FORM_TRIGGER_FORMS_HINT') }}
            </p>
          </div>
          <div>
            <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.FORM_TRIGGER_INBOX_LABEL') }}</label>
            <select
              :value="nodeProps.inbox_id || ''"
              :disabled="readOnly"
              :class="inputClass"
              @change="onFormTriggerInboxChange($event.target.value)"
            >
              <option value="" disabled>
                {{ $t('WORKFLOW.EDITOR.FORM_TRIGGER_INBOX_PLACEHOLDER') }}
              </option>
              <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
                {{ inbox.name }}
              </option>
            </select>
            <p class="mt-1.5 text-xs text-slate-500 dark:text-slate-400">
              {{ $t('WORKFLOW.EDITOR.FORM_TRIGGER_INBOX_HINT') }}
            </p>
          </div>
        </div>
        <WorkflowConditionsEditor
          v-if="!isFormSubmittedTrigger"
          :conditions="nodeProps.conditions || []"
          :event-name="nodeProps.event_name"
          :read-only="readOnly"
          @update:conditions="onConditionsUpdate"
        />
      </template>

      <template v-if="nodeType === 'wait' || nodeType === 'wait_for_reply'">
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
        <div v-if="nodeType === 'wait_for_reply'">
          <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.WAIT_RESPONDER_LABEL') }}</label>
          <select
            :value="nodeProps.wait_responder || 'contact'"
            :disabled="readOnly"
            :class="inputClass"
            @change="updateProp('wait_responder', $event.target.value)"
          >
            <option
              v-for="responder in WORKFLOW_WAIT_RESPONDERS"
              :key="responder.key"
              :value="responder.key"
            >
              {{ $t(responder.labelKey) }}
            </option>
          </select>
        </div>
        <p class="text-xs text-slate-500 dark:text-slate-400">
          {{
            nodeType === 'wait_for_reply'
              ? $t('WORKFLOW.EDITOR.WAIT_FOR_REPLY_HINT')
              : $t('WORKFLOW.EDITOR.WAIT_HINT')
          }}
        </p>
        <div v-if="nodeType === 'wait_for_reply'" class="space-y-2">
          <div class="flex items-center gap-2 p-2 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800">
            <div class="w-2 h-2 rounded-full bg-green-500 flex-shrink-0" />
            <p class="text-xs text-green-700 dark:text-green-300">{{ $t('WORKFLOW.EDITOR.BRANCH_REPLIED') }}</p>
          </div>
          <div class="flex items-center gap-2 p-2 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800">
            <div class="w-2 h-2 rounded-full bg-red-500 flex-shrink-0" />
            <p class="text-xs text-red-700 dark:text-red-300">{{ $t('WORKFLOW.EDITOR.BRANCH_TIMEOUT') }}</p>
          </div>
        </div>
      </template>

      <template v-if="nodeType === 'action'">
        <WorkflowActionList
          :node-id="node && node.id"
          :node-props="nodeProps"
          :read-only="readOnly"
          @update-node="patch => emit('update-node', patch)"
        />
      </template>

      <template v-if="nodeType === 'ai_outreach'">
        <WorkflowAiOutreachPanel
          :node-props="nodeProps"
          :read-only="readOnly"
          @update-node="patch => emit('update-node', patch)"
        />
      </template>

      <template v-if="nodeType === 'ai_conversation_analysis'">
        <WorkflowAiAnalysisPanel
          :node-props="nodeProps"
          :read-only="readOnly"
          @update-node="patch => emit('update-node', patch)"
        />
      </template>

      <template v-if="nodeType === 'ai_wait_for_intent'">
        <WorkflowAiWaitForIntentPanel
          :node-props="nodeProps"
          :read-only="readOnly"
          @update-node="patch => emit('update-node', patch)"
        />
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
