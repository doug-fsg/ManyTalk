<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import WorkflowsAPI from 'dashboard/api/workflows';
import { WORKFLOW_ACTION_TYPES } from './constants';
import KanbanStageSelect from 'dashboard/routes/dashboard/settings/macros/components/KanbanStageSelect.vue';
import AutomationFileInput from 'dashboard/components/widgets/AutomationFileInput.vue';
import {
  listExternalWhatsappInboxes,
  validateExternalWhatsappPhone,
  normalizeExternalWhatsappPhone,
} from './workflowWhatsappHelper';
import WorkflowMessageInput from './WorkflowMessageInput.vue';

const props = defineProps({
  action: { type: Object, required: true },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const store = useStore();
const isTestingWhatsapp = ref(false);

const agents = computed(() => store.getters['agents/getAgents'] || []);
const teams = computed(() => store.getters['teams/getTeams'] || []);
const labels = computed(() => store.getters['labels/getLabels'] || []);
const whatsappInboxes = computed(() =>
  listExternalWhatsappInboxes(store.getters['inboxes/getInboxes'] || [])
);

const actionName = computed(() => props.action?.action_name);
const actionParams = computed(() =>
  Array.isArray(props.action?.action_params) ? props.action.action_params : []
);

const actionInputType = computed(() => {
  if (!actionName.value) return null;
  return (
    WORKFLOW_ACTION_TYPES.find(a => a.key === actionName.value)?.inputType ||
    null
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
  const action = actionName.value;
  if (action === 'assign_agent')
    return agents.value.map(a => ({ id: a.id, name: a.name }));
  if (action === 'assign_team')
    return teams.value.map(tm => ({ id: tm.id, name: tm.name }));
  if (action === 'add_label' || action === 'remove_label')
    return labels.value.map(l => ({ id: l.title, name: l.title }));
  if (action === 'change_priority') return PRIORITY_OPTIONS;
  return [];
});

const whatsappPhoneError = computed(() => {
  const phone = actionParams.value[1];
  if (!phone) return null;
  const result = validateExternalWhatsappPhone(phone);
  return result.isValid ? null : result.messageKey;
});

const inputClass =
  'w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-500/30 disabled:opacity-50';
const labelClass =
  'block text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider mb-1.5';

const patchAction = patch => {
  emit('update', { ...props.action, ...patch });
};

const onMessageInput = value => {
  // Prefer string payload from WorkflowMessageInput; guard native Event fallbacks.
  const text =
    typeof value === 'string'
      ? value
      : (value && value.target && value.target.value) || '';
  patchAction({ action_params: [text] });
};

const onActionNameChange = newName => {
  patchAction({ action_name: newName, action_params: [] });
};

const onSingleSelectChange = value => {
  patchAction({ action_params: value ? [value] : [] });
};

const isLabelSelected = labelTitle => actionParams.value.includes(labelTitle);

const toggleLabel = labelTitle => {
  if (props.readOnly) return;
  const params = [...actionParams.value];
  const idx = params.indexOf(labelTitle);
  if (idx === -1) params.push(labelTitle);
  else params.splice(idx, 1);
  patchAction({ action_params: params });
};

const onKanbanStageChange = value => {
  if (!value || !value.length) {
    patchAction({ action_params: [] });
    return;
  }
  const pipelineId = value[0]?.id;
  const stageName = value[1]?.id || value[1]?.name;
  patchAction({ action_params: [pipelineId, stageName] });
};

const updateWhatsappParam = (index, value) => {
  const params = [...(actionParams.value.length ? actionParams.value : ['', '', ''])];
  while (params.length < 3) params.push('');
  params[index] = value;
  patchAction({ action_params: params });
};

const normalizeWhatsappPhoneField = () => {
  const params = [...(actionParams.value.length ? actionParams.value : ['', '', ''])];
  while (params.length < 3) params.push('');
  params[1] = normalizeExternalWhatsappPhone(params[1]);
  patchAction({ action_params: params });
};

const testWhatsappExternal = async () => {
  const params = actionParams.value;
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
  } catch (err) {
    const apiError = err?.response?.data?.error;
    const detail = err?.response?.data?.detail;
    const msg = detail || apiError;
    useAlert(
      msg
        ? `${t('WORKFLOW.EDITOR.WHATSAPP_TEST_ERROR')} (${msg})`
        : t('WORKFLOW.EDITOR.WHATSAPP_TEST_ERROR')
    );
  } finally {
    isTestingWhatsapp.value = false;
  }
};
</script>

<template>
  <div class="space-y-3 min-w-0">
    <div>
      <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.ACTION') }}</label>
      <select
        :value="actionName"
        :disabled="readOnly"
        :class="inputClass"
        name="workflow-action-name"
        @change="onActionNameChange($event.target.value)"
      >
        <option
          v-for="item in WORKFLOW_ACTION_TYPES"
          :key="item.key"
          :value="item.key"
        >
          {{ item.label }}
        </option>
      </select>
    </div>

    <div
      v-if="
        actionName === 'send_message' || actionName === 'add_private_note'
      "
    >
      <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.MESSAGE_LABEL') }}</label>
      <WorkflowMessageInput
        :value="actionParams[0] || ''"
        :disabled="readOnly"
        :input-class="inputClass + ' min-h-[100px]'"
        :placeholder="$t('WORKFLOW.EDITOR.MESSAGE_PLACEHOLDER')"
        :hint="
          actionName === 'send_message'
            ? $t('WORKFLOW.EDITOR.MESSAGE_VARIABLES_HINT')
            : ''
        "
        @input="onMessageInput"
      />
    </div>

    <div v-else-if="actionName === 'send_webhook_event'">
      <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.WEBHOOK_LABEL') }}</label>
      <input
        type="url"
        name="workflow-action-webhook"
        :value="actionParams[0] || ''"
        :disabled="readOnly"
        :class="inputClass"
        placeholder="https://"
        autocomplete="off"
        @input="patchAction({ action_params: [$event.target.value] })"
      />
    </div>

    <div v-else-if="actionName === 'send_whatsapp_external'" class="space-y-3">
      <p class="text-xs text-slate-500 dark:text-slate-400">
        {{ $t('WORKFLOW.EDITOR.WHATSAPP_EXTERNAL_HINT') }}
      </p>
      <div
        v-if="!whatsappInboxes.length"
        class="text-xs text-amber-600 dark:text-amber-400"
      >
        {{ $t('WORKFLOW.EDITOR.WHATSAPP_NO_INBOX') }}
      </div>
      <div v-else>
        <label :class="labelClass">{{
          $t('WORKFLOW.EDITOR.WHATSAPP_INBOX_LABEL')
        }}</label>
        <select
          :value="actionParams[0] || ''"
          :disabled="readOnly"
          :class="inputClass"
          name="workflow-action-whatsapp-inbox"
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
        <label :class="labelClass">{{
          $t('WORKFLOW.EDITOR.WHATSAPP_PHONE_LABEL')
        }}</label>
        <input
          type="tel"
          name="workflow-action-whatsapp-phone"
          :value="actionParams[1] || ''"
          :disabled="readOnly"
          :class="inputClass"
          :placeholder="$t('WORKFLOW.EDITOR.WHATSAPP_PHONE_PLACEHOLDER')"
          autocomplete="off"
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
        <WorkflowMessageInput
          :value="actionParams[2] || ''"
          :disabled="readOnly"
          :input-class="inputClass + ' min-h-[100px]'"
          :placeholder="$t('WORKFLOW.EDITOR.MESSAGE_PLACEHOLDER')"
          :hint="$t('WORKFLOW.EDITOR.MESSAGE_VARIABLES_HINT')"
          @input="updateWhatsappParam(2, $event)"
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

    <div v-else-if="actionInputType === 'kanban_stage_select'" class="space-y-2">
      <label :class="labelClass">Pipeline e Estágio</label>
      <KanbanStageSelect
        :value="actionParams"
        @input="onKanbanStageChange"
      />
    </div>

    <div v-else-if="actionInputType === 'search_select'">
      <label :class="labelClass">
        <template v-if="actionName === 'assign_agent'">Atendente</template>
        <template v-else-if="actionName === 'assign_team'">Equipe</template>
        <template v-else-if="actionName === 'change_priority'">Prioridade</template>
        <template v-else>Selecionar</template>
      </label>
      <select
        :value="actionParams[0] || ''"
        :disabled="readOnly"
        :class="inputClass"
        name="workflow-action-select"
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

    <div v-else-if="actionInputType === 'multi_select'" class="space-y-1.5">
      <label :class="labelClass">
        <template v-if="actionName === 'add_label'">Adicionar etiquetas</template>
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
          class="px-2 py-0.5 text-xs rounded-full border transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-500"
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
        v-if="actionParams.length"
        class="text-xs text-slate-400 dark:text-slate-500"
      >
        {{ actionParams.length }} selecionada(s)
      </p>
    </div>

    <div v-else-if="actionInputType === 'email'">
      <label :class="labelClass">Endereço de e-mail</label>
      <input
        type="email"
        name="workflow-action-email"
        :value="actionParams[0] || ''"
        :disabled="readOnly"
        :class="inputClass"
        placeholder="email@exemplo.com"
        autocomplete="off"
        spellcheck="false"
        @input="patchAction({ action_params: [$event.target.value] })"
      />
    </div>

    <div v-else-if="actionInputType === 'attachment'" class="space-y-1.5">
      <label :class="labelClass">Arquivo para enviar</label>
      <AutomationFileInput
        :value="actionParams"
        @input="patchAction({ action_params: $event })"
      />
      <p class="text-xs text-slate-400 dark:text-slate-500">
        O arquivo será enviado como mensagem na conversa.
      </p>
    </div>
  </div>
</template>
