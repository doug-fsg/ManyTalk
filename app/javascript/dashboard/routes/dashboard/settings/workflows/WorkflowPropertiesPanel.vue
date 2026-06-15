<script setup>
import { computed, ref, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import WorkflowsAPI from 'dashboard/api/workflows';
import {
  WORKFLOW_TRIGGER_EVENTS,
  WORKFLOW_ACTION_TYPES,
  WORKFLOW_WAIT_RESPONDERS,
} from './constants';
import WorkflowConditionsEditor from './WorkflowConditionsEditor.vue';
import WorkflowAiOutreachPanel from './WorkflowAiOutreachPanel.vue';
import WorkflowAiAnalysisPanel from './WorkflowAiAnalysisPanel.vue';
import KanbanStageSelect from 'dashboard/routes/dashboard/settings/macros/components/KanbanStageSelect.vue';
import AutomationFileInput from 'dashboard/components/widgets/AutomationFileInput.vue';
import {
  listExternalWhatsappInboxes,
  validateExternalWhatsappPhone,
  normalizeExternalWhatsappPhone,
} from './workflowWhatsappHelper';

const props = defineProps({
  node: { type: Object, default: null },
  readOnly: { type: Boolean, default: false },
  nodeErrors: { type: Array, default: () => [] },
});

const emit = defineEmits(['update-node']);
const { t } = useI18n();
const store = useStore();
const isTestingWhatsapp = ref(false);

onMounted(async () => {
  await Promise.all([
    store.dispatch('agents/get'),
    store.dispatch('teams/get'),
    store.dispatch('labels/get'),
    store.dispatch('attributes/get'),
    store.dispatch('inboxes/get'),
  ]);
});

const agents = computed(() => store.getters['agents/getAgents'] || []);
const teams = computed(() => store.getters['teams/getTeams'] || []);
const labels = computed(() => store.getters['labels/getLabels'] || []);

const whatsappInboxes = computed(() =>
  listExternalWhatsappInboxes(store.getters['inboxes/getInboxes'] || [])
);

const whatsappPhoneError = computed(() => {
  const phone = (nodeProps.value.action_params || [])[1];
  if (!phone) return null;
  const result = validateExternalWhatsappPhone(phone);
  return result.isValid ? null : result.messageKey;
});

const nodeType = computed(() => {
  const node = props.node;
  return node && node.properties && node.properties.workflowNodeType;
});
const nodeProps = computed(() => {
  const node = props.node;
  return (node && node.properties) || {};
});

const actionInputType = computed(() => {
  if (!nodeProps.value.action_name) return null;
  return (
    WORKFLOW_ACTION_TYPES.find(a => a.key === nodeProps.value.action_name)
      ?.inputType || null
  );
});

const PRIORITY_OPTIONS = [
  { id: 'none', name: 'Nenhuma' },
  { id: 'low', name: 'Baixa' },
  { id: 'medium', name: 'Média' },
  { id: 'high', name: 'Alta' },
  { id: 'urgent', name: 'Urgente' },
];

const actionDropdownOptions = computed(() => {
  const action = nodeProps.value.action_name;
  if (action === 'assign_agent')
    return agents.value.map(a => ({ id: a.id, name: a.name }));
  if (action === 'assign_team')
    return teams.value.map(tm => ({ id: tm.id, name: tm.name }));
  if (action === 'add_label' || action === 'remove_label')
    return labels.value.map(l => ({ id: l.title, name: l.title }));
  if (action === 'change_priority') return PRIORITY_OPTIONS;
  return [];
});

const updateProp = (key, value) => emit('update-node', { [key]: value });

const onConditionsUpdate = conditions => updateProp('conditions', conditions);

const onTriggerEventChange = event => {
  emit('update-node', { event_name: event, conditions: [] });
};

const onActionNameChange = newName => {
  emit('update-node', { action_name: newName, action_params: [] });
};

// Single search_select: backend expects [id]
const onSingleSelectChange = value => {
  updateProp('action_params', value ? [value] : []);
};

// Multi-select labels: backend expects [labelTitle, ...]
const isLabelSelected = labelTitle => {
  return (nodeProps.value.action_params || []).includes(labelTitle);
};

const toggleLabel = labelTitle => {
  const params = [...(nodeProps.value.action_params || [])];
  const idx = params.indexOf(labelTitle);
  if (idx === -1) params.push(labelTitle);
  else params.splice(idx, 1);
  updateProp('action_params', params);
};

// KanbanStageSelect emits [{id: pipelineId, name}, {id: stageName, name}]
// Backend expects [pipelineId, stageName]
const onKanbanStageChange = value => {
  if (!value || !value.length) {
    updateProp('action_params', []);
    return;
  }
  const pipelineId = value[0]?.id;
  const stageName = value[1]?.id || value[1]?.name;
  updateProp('action_params', [pipelineId, stageName]);
};

const updateWhatsappParam = (index, value) => {
  const params = [...(nodeProps.value.action_params || ['', '', ''])];
  params[index] = value;
  emit('update-node', { action_params: params });
};

const normalizeWhatsappPhoneField = () => {
  const params = [...(nodeProps.value.action_params || ['', '', ''])];
  params[1] = normalizeExternalWhatsappPhone(params[1]);
  emit('update-node', { action_params: params });
};

const testWhatsappExternal = async () => {
  const params = nodeProps.value.action_params || [];
  const inboxId = params[0];
  const phoneNumber = params[1];
  const message = params[2];

  if (!inboxId || !phoneNumber) {
    useAlert(t('WORKFLOW.EDITOR.WHATSAPP_TEST_ERROR'));
    return;
  }

  isTestingWhatsapp.value = true;
  try {
    await WorkflowsAPI.testExternalWhatsapp({
      inboxId,
      phoneNumber,
      message: message || t('WORKFLOW.EDITOR.MESSAGE_PLACEHOLDER'),
    });
    useAlert(t('WORKFLOW.EDITOR.WHATSAPP_TEST_SUCCESS'));
  } catch {
    useAlert(t('WORKFLOW.EDITOR.WHATSAPP_TEST_ERROR'));
  } finally {
    isTestingWhatsapp.value = false;
  }
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
          {{ $t('WORKFLOW.EDITOR.NODE_SETTINGS') }}
        </p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
          {{ $t('WORKFLOW.EDITOR.SELECT_NODE_HINT') }}
        </p>
      </template>
    </div>

    <div v-if="node && nodeType" class="flex-1 overflow-y-auto p-4 space-y-5 min-w-0">
      <div
        v-if="nodeErrors.length"
        class="flex items-start gap-2 -mt-1 mb-1 text-xs text-amber-800/90 dark:text-amber-300/90"
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

      <div>
          <label :class="labelClass">Nome da etapa</label>
          <input
            type="text"
            :value="nodeProps.label || ''"
            :disabled="readOnly"
            :class="inputClass"
            placeholder="Ex: Follow-up 1 — 6h"
            @input="updateProp('label', $event.target.value)"
          />
          <p class="text-xs text-slate-400 mt-1">Exibido ao atendente no painel da conversa</p>
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
        <div>
          <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.ACTION') }}</label>
          <select
            :value="nodeProps.action_name"
            :disabled="readOnly"
            :class="inputClass"
            @change="onActionNameChange($event.target.value)"
          >
            <option v-for="action in WORKFLOW_ACTION_TYPES" :key="action.key" :value="action.key">
              {{ action.label }}
            </option>
          </select>
        </div>

        <!-- Mensagem / nota privada -->
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

        <!-- Webhook URL -->
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

        <!-- WhatsApp externo -->
        <div v-else-if="nodeProps.action_name === 'send_whatsapp_external'" class="space-y-3">
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('WORKFLOW.EDITOR.WHATSAPP_EXTERNAL_HINT') }}
          </p>
          <div v-if="!whatsappInboxes.length" class="text-xs text-amber-600 dark:text-amber-400">
            {{ $t('WORKFLOW.EDITOR.WHATSAPP_NO_INBOX') }}
          </div>
          <div v-else>
            <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.WHATSAPP_INBOX_LABEL') }}</label>
            <select
              :value="(nodeProps.action_params && nodeProps.action_params[0]) || ''"
              :disabled="readOnly"
              :class="inputClass"
              @change="updateWhatsappParam(0, $event.target.value)"
            >
              <option value="">{{ $t('WORKFLOW.EDITOR.WHATSAPP_SELECT_INBOX') }}</option>
              <option
                v-for="inbox in whatsappInboxes"
                :key="inbox.id"
                :value="inbox.id"
              >
                {{ inbox.name }}
              </option>
            </select>
          </div>
          <div>
            <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.WHATSAPP_PHONE_LABEL') }}</label>
            <input
              type="tel"
              :value="(nodeProps.action_params && nodeProps.action_params[1]) || ''"
              :disabled="readOnly"
              :class="inputClass"
              :placeholder="$t('WORKFLOW.EDITOR.WHATSAPP_PHONE_PLACEHOLDER')"
              @input="updateWhatsappParam(1, $event.target.value)"
              @blur="normalizeWhatsappPhoneField"
            />
            <p
              v-if="whatsappPhoneError"
              class="text-xs text-amber-600 dark:text-amber-400 mt-1"
            >
              {{ $t(whatsappPhoneError) }}
            </p>
          </div>
          <div>
            <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.MESSAGE_LABEL') }}</label>
            <textarea
              :value="(nodeProps.action_params && nodeProps.action_params[2]) || ''"
              :disabled="readOnly"
              :class="inputClass + ' min-h-[100px]'"
              :placeholder="$t('WORKFLOW.EDITOR.MESSAGE_PLACEHOLDER')"
              @input="updateWhatsappParam(2, $event.target.value)"
            />
          </div>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            :disabled="readOnly"
            :is-loading="isTestingWhatsapp"
            @click="testWhatsappExternal"
          >
            {{ $t('WORKFLOW.EDITOR.WHATSAPP_TEST') }}
          </woot-button>
        </div>

        <!-- Pipeline / estágio (kanban_stage_select) -->
        <div v-else-if="actionInputType === 'kanban_stage_select'" class="space-y-2">
          <label :class="labelClass">Pipeline e Estágio</label>
          <KanbanStageSelect
            :value="nodeProps.action_params || []"
            @input="onKanbanStageChange"
          />
        </div>

        <!-- Seleção única: atendente, equipe, prioridade, SLA (search_select) -->
        <div v-else-if="actionInputType === 'search_select'">
          <label :class="labelClass">
            <template v-if="nodeProps.action_name === 'assign_agent'">Atendente</template>
            <template v-else-if="nodeProps.action_name === 'assign_team'">Equipe</template>
            <template v-else-if="nodeProps.action_name === 'change_priority'">Prioridade</template>
            <template v-else>Selecionar</template>
          </label>
          <select
            :value="(nodeProps.action_params && nodeProps.action_params[0]) || ''"
            :disabled="readOnly"
            :class="inputClass"
            @change="onSingleSelectChange($event.target.value)"
          >
            <option value="">— Selecionar —</option>
            <option
              v-for="opt in actionDropdownOptions"
              :key="opt.id"
              :value="opt.id"
            >
              {{ opt.name }}
            </option>
          </select>
          <p
            v-if="!actionDropdownOptions.length"
            class="text-xs text-amber-600 dark:text-amber-400 mt-1"
          >
            Nenhum item disponível. Verifique as configurações da conta.
          </p>
        </div>

        <!-- Seleção múltipla: etiquetas (multi_select) -->
        <div v-else-if="actionInputType === 'multi_select'" class="space-y-1.5">
          <label :class="labelClass">
            <template v-if="nodeProps.action_name === 'add_label'">Adicionar etiquetas</template>
            <template v-else>Remover etiquetas</template>
          </label>
          <div
            v-if="!labels.length"
            class="text-xs text-amber-600 dark:text-amber-400"
          >
            Nenhuma etiqueta disponível.
          </div>
          <div
            v-else
            class="flex flex-wrap gap-1.5 p-2 border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 max-h-40 overflow-y-auto"
          >
            <button
              v-for="label in labels"
              :key="label.id"
              type="button"
              :disabled="readOnly"
              class="px-2 py-0.5 text-xs rounded-full border transition-colors"
              :class="
                isLabelSelected(label.title)
                  ? 'bg-woot-500 border-woot-500 text-white'
                  : 'border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:border-woot-400'
              "
              @click="toggleLabel(label.title)"
            >
              {{ label.title }}
            </button>
          </div>
          <p
            v-if="(nodeProps.action_params || []).length"
            class="text-xs text-slate-400 dark:text-slate-500"
          >
            {{ (nodeProps.action_params || []).length }} selecionada(s)
          </p>
        </div>

        <!-- E-mail de transcrição -->
        <div v-else-if="actionInputType === 'email'">
          <label :class="labelClass">Endereço de e-mail</label>
          <input
            type="email"
            :value="(nodeProps.action_params && nodeProps.action_params[0]) || ''"
            :disabled="readOnly"
            :class="inputClass"
            placeholder="email@exemplo.com"
            @input="updateProp('action_params', [$event.target.value])"
          />
        </div>

        <!-- Enviar anexo -->
        <div v-else-if="actionInputType === 'attachment'" class="space-y-1.5">
          <label :class="labelClass">Arquivo para enviar</label>
          <AutomationFileInput
            :value="nodeProps.action_params || []"
            @input="updateProp('action_params', $event)"
          />
          <p class="text-xs text-slate-400 dark:text-slate-500">
            O arquivo será enviado como mensagem na conversa.
          </p>
        </div>
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
