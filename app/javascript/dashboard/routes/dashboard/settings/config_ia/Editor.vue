<script setup>
import { computed, nextTick, provide, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import { useRoute, useRouter } from 'dashboard/composables/route';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import AiAttendantAPI from 'dashboard/api/aiAttendant';
import AiAttendantVariableField from './AiAttendantVariableField.vue';
import BehaviorStepsEditor from './BehaviorStepsEditor.vue';
import ReferenceFilesEditor from './ReferenceFilesEditor.vue';
import AiAttendantTestModal from './AiAttendantTestModal.vue';
import AiAttendantHandoffModal from './AiAttendantHandoffModal.vue';
import {
  HANDOFF_PRESET_KEYS,
  parseHandoffConditions,
} from './aiAttendantHandoffPresets';
import {
  FILE_VARIABLES_KEY,
  VARIABLE_INSERT_KEY,
} from './aiAttendantVariables';
import { findFirstUnlinkedAttachmentIssue } from './aiAttendantAttachmentValidation';
import {
  DEFAULT_AVATAR_ID,
  avatarPreviewUrl,
  isValidAvatarId,
} from './aiAttendantAvatars';
import AiAttendantAvatarPicker from './AiAttendantAvatarPicker.vue';

const inputStyles = {
  borderRadius: '12px',
  padding: '6px 12px',
  fontSize: '14px',
};

const TAB_KEYS = ['identity', 'playbook', 'rules', 'operation'];

const emptyForm = () => ({
  inbox_ids: [],
  avatar_id: DEFAULT_AVATAR_ID,
  digital_agent_name: '',
  agent_role: '',
  agent_duties: '',
  agent_objective: '',
  behavior_step_mode: 'guide',
  company_context: '',
  topics_to_avoid_text: '',
  handoff_conditions: '',
  handoff_customer_message: '',
  schedule_mode: 'always',
  detect_language: false,
  debounce_seconds: 5,
  active: false,
});

const store = useStore();
const getters = useStoreGetters();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const form = ref(emptyForm());
const existingPauseReason = ref(null);
const isSaving = ref(false);
const isLoading = ref(false);
const showTestPopup = ref(false);
const showHandoffModal = ref(false);
const showTopicsField = ref(false);
const showHandoffMessageField = ref(false);
const behaviorStepsEditorRef = ref(null);
const referenceFilesEditorRef = ref(null);
const behaviorStepsSeed = ref([]);
const referenceFilesSeed = ref([]);
const activeTabIndex = ref(0);
const fileVariables = ref([]);
const variableInsertTarget = ref(null);
const fileSavePayload = ref({
  reference_file_blob_ids: [],
  remove_reference_file_ids: [],
});
const selectedInboxes = ref([]);

provide(FILE_VARIABLES_KEY, fileVariables);
provide(VARIABLE_INSERT_KEY, variableInsertTarget);

const tabs = computed(() => [
  { key: 'identity', name: t('AI_ATTENDANT.TABS.IDENTITY') },
  { key: 'playbook', name: t('AI_ATTENDANT.TABS.PLAYBOOK') },
  { key: 'rules', name: t('AI_ATTENDANT.TABS.RULES') },
  { key: 'operation', name: t('AI_ATTENDANT.TABS.OPERATION') },
]);

const activeTabKey = computed(
  () => tabs.value[activeTabIndex.value]?.key ?? TAB_KEYS[0]
);

const showVariablesHint = computed(
  () => activeTabKey.value === 'rules' || activeTabKey.value === 'identity'
);

const configId = computed(() => route.params.configId);
const isEdit = computed(() => Boolean(configId.value));
const inboxes = computed(() => getters['inboxes/getInboxes']?.value || []);
const scheduleModes = ['always', 'within_inbox_hours', 'outside_inbox_hours'];

const inboxIdsFromConfig = config => {
  if (Array.isArray(config?.inbox_ids) && config.inbox_ids.length) {
    return config.inbox_ids.map(id => Number(id));
  }
  if (config?.inbox_id) return [Number(config.inbox_id)];
  return [];
};

const syncSelectedInboxesFromForm = () => {
  const ids = (form.value.inbox_ids || []).map(Number);
  selectedInboxes.value = inboxes.value.filter(inbox =>
    ids.includes(Number(inbox.id))
  );
};

watch(
  () => [inboxes.value, form.value.inbox_ids],
  () => syncSelectedInboxesFromForm(),
  { deep: true }
);

const onInboxesChange = value => {
  selectedInboxes.value = value || [];
  form.value.inbox_ids = (value || []).map(inbox => Number(inbox.id));
};

const linesToArray = value =>
  (value || '')
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean);

const arrayToLines = value => {
  if (!Array.isArray(value)) return '';
  return value
    .map(line => String(line).trim())
    .filter(Boolean)
    .join('\n');
};

const normalizeBehaviorSteps = value => {
  if (!Array.isArray(value)) return [];
  return value
    .map(item => {
      if (typeof item === 'string') {
        return { instruction: item.trim(), completion_criterion: '' };
      }
      return {
        instruction: (item.instruction || '').trim(),
        completion_criterion: (item.completion_criterion || '').trim(),
      };
    })
    .filter(step => step.instruction.length > 0);
};

const canActivate = computed(() =>
  Boolean(form.value.digital_agent_name.trim())
);

const pauseReasonForSave = active => {
  if (active) return null;
  if (existingPauseReason.value === 'no_credits') return 'no_credits';
  if (isEdit.value) return 'admin';
  return null;
};

const payload = () => {
  const active = form.value.active && canActivate.value;
  return {
    inbox_ids: (form.value.inbox_ids || []).map(Number).filter(Boolean),
    avatar_id: form.value.avatar_id,
    digital_agent_name: form.value.digital_agent_name,
    agent_role: form.value.agent_role,
    agent_duties: form.value.agent_duties,
    agent_objective: form.value.agent_objective,
    behavior_steps: normalizeBehaviorSteps(
      behaviorStepsEditorRef.value?.getStepsForSave?.() ?? []
    ),
    behavior_step_mode: form.value.behavior_step_mode || 'guide',
    company_context: form.value.company_context,
    topics_to_avoid: linesToArray(form.value.topics_to_avoid_text),
    handoff_conditions: form.value.handoff_conditions,
    handoff_customer_message: form.value.handoff_customer_message,
    schedule_mode: form.value.schedule_mode,
    detect_language: form.value.detect_language,
    debounce_seconds: Number(form.value.debounce_seconds) || 5,
    active,
    pause_reason: pauseReasonForSave(active),
    ...fileSavePayload.value,
    ...referenceFilesEditorRef.value?.getSavePayload?.(),
  };
};

const applyConfig = config => {
  existingPauseReason.value = config.pause_reason;
  form.value = {
    inbox_ids: inboxIdsFromConfig(config),
    avatar_id: isValidAvatarId(config.avatar_id)
      ? config.avatar_id
      : DEFAULT_AVATAR_ID,
    digital_agent_name: config.digital_agent_name || '',
    agent_role: config.agent_role || '',
    agent_duties: config.agent_duties || '',
    agent_objective: config.agent_objective || '',
    behavior_step_mode: config.behavior_step_mode || 'guide',
    company_context: config.company_context || '',
    topics_to_avoid_text: arrayToLines(config.topics_to_avoid),
    handoff_conditions: config.handoff_conditions || '',
    handoff_customer_message: config.handoff_customer_message || '',
    schedule_mode: config.schedule_mode || 'always',
    detect_language: Boolean(config.detect_language),
    debounce_seconds: config.debounce_seconds || 5,
    active: Boolean(config.active),
  };
  behaviorStepsSeed.value = normalizeBehaviorSteps(config.behavior_steps);
  referenceFilesSeed.value = config.reference_files || [];
  showTopicsField.value = Boolean(form.value.topics_to_avoid_text);
  showHandoffMessageField.value = Boolean(form.value.handoff_customer_message);
};

const loadEditor = async () => {
  store.dispatch('inboxes/get');
  activeTabIndex.value = 0;
  if (!configId.value) {
    existingPauseReason.value = null;
    form.value = emptyForm();
    behaviorStepsSeed.value = [];
    referenceFilesSeed.value = [];
    showTopicsField.value = false;
    showHandoffMessageField.value = false;
    return;
  }
  isLoading.value = true;
  try {
    const response = await AiAttendantAPI.show(configId.value);
    applyConfig(response.data);
  } catch (error) {
    useAlert(t('AI_ATTENDANT.ERROR'));
    router.push({ name: 'settings_ia' });
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => route.params.configId,
  () => {
    loadEditor();
  },
  { immediate: true }
);

const onTabChange = index => {
  activeTabIndex.value = index;
};

const goToTab = key => {
  const index = tabs.value.findIndex(tab => tab.key === key);
  if (index >= 0) activeTabIndex.value = index;
};

const scrollToAnchor = anchorId => {
  if (!anchorId) return;
  const element = document.getElementById(anchorId);
  element?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  const focusable = element?.querySelector('textarea, input');
  focusable?.focus({ preventScroll: true });
};

const revealFieldForAnchor = anchorId => {
  if (anchorId === 'ia-field-topics_to_avoid') {
    showTopicsField.value = true;
  }
  if (anchorId === 'ia-field-handoff_message') {
    showHandoffMessageField.value = true;
  }
};

const validateBeforeSave = async () => {
  if (!form.value.inbox_ids?.length) {
    useAlert(t('AI_ATTENDANT.FORM.INBOX.ERROR'));
    goToTab('identity');
    return false;
  }
  if (!isValidAvatarId(form.value.avatar_id)) {
    useAlert(t('AI_ATTENDANT.FORM.AVATAR.ERROR'));
    goToTab('identity');
    return false;
  }
  if (form.value.active && !canActivate.value) {
    useAlert(t('AI_ATTENDANT.TOGGLE.ERROR_ACTIVE'));
    goToTab('identity');
    return false;
  }
  if (referenceFilesEditorRef.value?.isUploadingFiles?.()) {
    useAlert(t('AI_ATTENDANT.FORM.FILES.UPLOADING'));
    goToTab('rules');
    return false;
  }
  if (referenceFilesEditorRef.value?.hasInvalidNames?.()) {
    useAlert(t('AI_ATTENDANT.FORM.FILES.NAME_REQUIRED'));
    goToTab('rules');
    return false;
  }

  const steps = behaviorStepsEditorRef.value?.getLocalSteps?.() ?? [];
  const issue = findFirstUnlinkedAttachmentIssue(
    form.value,
    steps,
    fileVariables.value
  );
  if (issue) {
    useAlert(
      t('AI_ATTENDANT.FORM.FILES.TOKEN_SAVE_BLOCKED', { token: issue.token })
    );
    revealFieldForAnchor(issue.anchorId);
    goToTab(issue.tab);
    await nextTick();
    await nextTick();
    scrollToAnchor(issue.anchorId);
    return false;
  }

  return true;
};

const persistConfig = async ({ stayOnPage = false, silent = false } = {}) => {
  if (!(await validateBeforeSave())) return false;

  isSaving.value = true;
  try {
    if (isEdit.value) {
      const response = await AiAttendantAPI.update(
        configId.value,
        payload()
      );
      if (stayOnPage) {
        applyConfig(response.data);
      } else if (!silent) {
        useAlert(t('AI_ATTENDANT.EDIT.API.SUCCESS_MESSAGE'));
      }
    } else {
      const response = await AiAttendantAPI.create(payload());
      if (stayOnPage) {
        await router.replace({
          name: 'settings_ia_edit',
          params: { configId: response.data.id },
        });
        applyConfig(response.data);
      } else if (!silent) {
        useAlert(t('AI_ATTENDANT.ADD.API.SUCCESS_MESSAGE'));
      }
    }

    if (!stayOnPage) {
      router.push({ name: 'settings_ia' });
    }
    return true;
  } catch (error) {
    const key = isEdit.value
      ? 'AI_ATTENDANT.EDIT.API.ERROR_MESSAGE'
      : 'AI_ATTENDANT.ADD.API.ERROR_MESSAGE';
    useAlert(t(key));
    return false;
  } finally {
    isSaving.value = false;
  }
};

const onToggleActive = nextActive => {
  if (nextActive && !canActivate.value) {
    useAlert(t('AI_ATTENDANT.TOGGLE.ERROR_ACTIVE'));
    form.value.active = false;
    goToTab('identity');
    return;
  }
  form.value.active = nextActive;
};

const save = async () => {
  await persistConfig();
};

const openTestPopup = async () => {
  const saved = await persistConfig({ stayOnPage: true, silent: true });
  if (saved) showTestPopup.value = true;
};

const closeTestPopup = () => {
  showTestPopup.value = false;
};

const handoffPresetLabels = computed(() =>
  Object.fromEntries(
    HANDOFF_PRESET_KEYS.map(key => [
      key,
      t(`AI_ATTENDANT.FORM.HANDOFF_PRESETS.${key}`),
    ])
  )
);

const parsedHandoff = computed(() =>
  parseHandoffConditions(form.value.handoff_conditions, handoffPresetLabels.value)
);

const handoffSummary = computed(() => {
  const count = parsedHandoff.value.selected.length;
  const hasExtra = Boolean(parsedHandoff.value.extra);
  if (!count && !hasExtra) {
    return t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.EMPTY');
  }
  if (count && hasExtra) {
    return t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.SUMMARY_WITH_EXTRA', {
      count,
    });
  }
  if (count) {
    return t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.SUMMARY', { count });
  }
  return t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.SUMMARY_CUSTOM');
});

const applyHandoffConditions = value => {
  form.value.handoff_conditions = value;
};

const testAgentName = computed(
  () => form.value.digital_agent_name || t('AI_ATTENDANT.LIST.UNNAMED_AGENT')
);

const testAvatarUrl = computed(() =>
  avatarPreviewUrl(form.value.avatar_id)
);

const testInboxName = computed(() => {
  const ids = (form.value.inbox_ids || []).map(Number).filter(Boolean);
  if (!ids.length) return '—';
  return ids
    .map(id => {
      const inbox = inboxes.value.find(item => Number(item.id) === id);
      return (
        inbox?.name ||
        t('AI_ATTENDANT.LIST.UNKNOWN_INBOX', { id })
      );
    })
    .join(', ');
});
</script>

<template>
  <div class="flex flex-col w-full min-h-[calc(100dvh-11rem)]">
    <woot-loading-state
      v-if="isLoading"
      :message="$t('AI_ATTENDANT.LOADING')"
    />
    <form
      v-else
      class="flex flex-col flex-1 w-full min-h-[calc(100dvh-11rem)]"
      @submit.prevent="save"
    >
      <div class="flex-shrink-0 pb-4 border-b border-slate-50 dark:border-slate-800/50">
        <h2
          class="text-xl font-semibold text-slate-900 dark:text-slate-25 mb-4"
        >
          {{
            isEdit
              ? $t('AI_ATTENDANT.EDIT.TITLE')
              : $t('AI_ATTENDANT.ADD.TITLE')
          }}
        </h2>
        <woot-tabs
          class="ia-editor-tabs"
          :index="activeTabIndex"
          :border="false"
          @change="onTabChange"
        >
          <woot-tabs-item
            v-for="tab in tabs"
            :key="tab.key"
            :name="tab.name"
            :show-badge="false"
          />
        </woot-tabs>
      </div>

      <div
        class="flex-1 w-full py-6 pb-28"
        :class="
          activeTabKey === 'playbook' || activeTabKey === 'identity'
            ? 'max-w-5xl'
            : 'max-w-3xl'
        "
      >
        <p
          v-if="showVariablesHint"
          class="text-xs text-slate-500 dark:text-slate-400 leading-5 m-0 mb-6"
        >
          {{ $t('AI_ATTENDANT.FORM.VARIABLES_HINT') }}
        </p>

        <div
          v-show="activeTabKey === 'identity'"
          class="grid grid-cols-1 lg:grid-cols-5 gap-6 lg:gap-8 items-start w-full"
        >
          <div
            class="ia-identity-setup flex flex-col gap-4 min-w-0 lg:col-span-2"
          >
            <div class="flex flex-wrap items-end gap-4">
              <AiAttendantAvatarPicker
                v-model="form.avatar_id"
                class="shrink-0"
              />
              <woot-input
                v-model="form.digital_agent_name"
                class="ia-agent-name-input flex-1 min-w-[10rem] max-w-xs mb-0"
                :label="$t('AI_ATTENDANT.FORM.NAME.LABEL')"
                :placeholder="$t('AI_ATTENDANT.FORM.NAME.PLACEHOLDER')"
              />
            </div>

            <label class="input-container min-w-0 mb-0">
              <span>{{ $t('AI_ATTENDANT.FORM.INBOX.LABEL') }}</span>
              <div class="ia-inbox-multiselect">
                <multiselect
                  v-model="selectedInboxes"
                  class="no-margin"
                  :options="inboxes"
                  track-by="id"
                  label="name"
                  :multiple="true"
                  :close-on-select="false"
                  :clear-on-select="false"
                  :hide-selected="true"
                  :placeholder="$t('AI_ATTENDANT.FORM.INBOX.PLACEHOLDER')"
                  selected-label
                  :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
                  :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
                  @input="onInboxesChange"
                />
              </div>
            </label>
          </div>

          <div
            class="flex flex-col gap-4 min-w-0 lg:col-span-3 rounded-xl border border-solid border-slate-200 dark:border-slate-600 p-4"
          >
            <p
              class="text-sm font-medium text-slate-800 dark:text-slate-100 m-0"
            >
              {{ $t('AI_ATTENDANT.SECTIONS.PERSONA') }}
            </p>

            <label class="mb-0">
              {{ $t('AI_ATTENDANT.FORM.ROLE.LABEL') }}
              <AiAttendantVariableField
                id="ia-field-agent_role"
                v-model="form.agent_role"
                :rows="3"
                :placeholder="$t('AI_ATTENDANT.FORM.ROLE.PLACEHOLDER')"
              />
            </label>

            <label class="mb-0">
              {{ $t('AI_ATTENDANT.FORM.DUTIES.LABEL') }}
              <AiAttendantVariableField
                id="ia-field-agent_duties"
                v-model="form.agent_duties"
                :rows="3"
                :placeholder="$t('AI_ATTENDANT.FORM.DUTIES.PLACEHOLDER')"
              />
            </label>

            <label class="mb-0">
              {{ $t('AI_ATTENDANT.FORM.OBJECTIVE.LABEL') }}
              <AiAttendantVariableField
                id="ia-field-agent_objective"
                v-model="form.agent_objective"
                :rows="3"
                :placeholder="$t('AI_ATTENDANT.FORM.OBJECTIVE.PLACEHOLDER')"
              />
            </label>
          </div>
        </div>

        <div v-show="activeTabKey === 'playbook'" class="w-full max-w-none">
          <BehaviorStepsEditor
            ref="behaviorStepsEditorRef"
            :initial-steps="behaviorStepsSeed"
            :mode="form.behavior_step_mode"
            @update:mode="form.behavior_step_mode = $event"
          />
        </div>

        <div v-show="activeTabKey === 'rules'" class="flex flex-col">
          <label>
            {{ $t('AI_ATTENDANT.FORM.COMPANY.LABEL') }}
            <AiAttendantVariableField
              id="ia-field-company_context"
              v-model="form.company_context"
              :rows="4"
              :placeholder="$t('AI_ATTENDANT.FORM.COMPANY.PLACEHOLDER')"
            />
          </label>

          <ReferenceFilesEditor
            ref="referenceFilesEditorRef"
            :initial-files="referenceFilesSeed"
            @update:variables="fileVariables = $event"
            @update:save-payload="fileSavePayload = $event"
          />

          <div class="mt-4 mb-2">
            <button
              type="button"
              class="text-xs text-slate-500 dark:text-slate-400 hover:text-woot-600 dark:hover:text-woot-300 p-0 bg-transparent border-0 cursor-pointer"
              @click="showTopicsField = !showTopicsField"
            >
              {{
                showTopicsField
                  ? $t('AI_ATTENDANT.FORM.TOPICS.HIDE')
                  : $t('AI_ATTENDANT.FORM.TOPICS.SHOW')
              }}
            </button>
            <label v-if="showTopicsField" class="mt-2">
              {{ $t('AI_ATTENDANT.FORM.TOPICS.LABEL') }}
              <AiAttendantVariableField
                id="ia-field-topics_to_avoid"
                v-model="form.topics_to_avoid_text"
                :rows="3"
                :placeholder="$t('AI_ATTENDANT.FORM.TOPICS.PLACEHOLDER')"
              />
            </label>
          </div>

          <p
            class="text-sm font-medium text-slate-800 dark:text-slate-100 mt-4 mb-3"
          >
            {{ $t('AI_ATTENDANT.SECTIONS.HANDOFF') }}
          </p>

          <div
            class="flex flex-wrap items-center justify-between gap-2 px-3 py-3 mb-3 rounded-xl border border-solid border-slate-200 dark:border-slate-600"
          >
            <div class="min-w-0">
              <p class="mb-0 text-sm font-medium text-slate-800 dark:text-slate-100">
                {{ $t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.LABEL') }}
              </p>
              <p class="mb-0 text-xs text-slate-500 dark:text-slate-400 mt-1">
                {{ handoffSummary }}
              </p>
            </div>
            <woot-button
              type="button"
              variant="smooth"
              color-scheme="secondary"
              size="small"
              @click.prevent="showHandoffModal = true"
            >
              {{ $t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.OPEN') }}
            </woot-button>
          </div>

          <div class="mb-2">
            <button
              type="button"
              class="text-xs text-slate-500 dark:text-slate-400 hover:text-woot-600 dark:hover:text-woot-300 p-0 bg-transparent border-0 cursor-pointer"
              @click="showHandoffMessageField = !showHandoffMessageField"
            >
              {{
                showHandoffMessageField
                  ? $t('AI_ATTENDANT.FORM.HANDOFF_MESSAGE.HIDE')
                  : $t('AI_ATTENDANT.FORM.HANDOFF_MESSAGE.SHOW')
              }}
            </button>
            <label v-if="showHandoffMessageField" class="mt-2">
              {{ $t('AI_ATTENDANT.FORM.HANDOFF_MESSAGE.LABEL') }}
              <AiAttendantVariableField
                id="ia-field-handoff_message"
                v-model="form.handoff_customer_message"
                :rows="2"
                :placeholder="
                  $t('AI_ATTENDANT.FORM.HANDOFF_MESSAGE.PLACEHOLDER')
                "
              />
            </label>
          </div>
        </div>

        <div v-show="activeTabKey === 'operation'" class="flex flex-col">
          <label>
            {{ $t('AI_ATTENDANT.FORM.SCHEDULE.LABEL') }}
            <select v-model="form.schedule_mode">
              <option v-for="mode in scheduleModes" :key="mode" :value="mode">
                {{ $t(`AI_ATTENDANT.SCHEDULE.${mode}`) }}
              </option>
            </select>
          </label>

          <woot-input
            v-model="form.debounce_seconds"
            class="w-full"
            type="number"
            :styles="inputStyles"
            :label="$t('AI_ATTENDANT.FORM.DEBOUNCE.LABEL')"
          />

          <div
            class="flex min-h-10 items-center text-sm w-full gap-2 border border-solid border-slate-200 dark:border-slate-600 px-3 py-2 rounded-xl justify-between mb-4"
          >
            <span class="text-slate-700 dark:text-slate-200">
              {{ $t('AI_ATTENDANT.FORM.DETECT_LANGUAGE.LABEL') }}
            </span>
            <woot-switch
              :value="form.detect_language"
              @input="form.detect_language = $event"
            />
          </div>

          <div
            class="flex min-h-10 items-center text-sm w-full gap-2 border border-solid border-slate-200 dark:border-slate-600 px-3 py-2 rounded-xl justify-between"
          >
            <span class="text-slate-700 dark:text-slate-200">
              {{ $t('AI_ATTENDANT.FORM.ACTIVE.LABEL') }}
            </span>
            <woot-switch :value="form.active" @input="onToggleActive" />
          </div>
        </div>
      </div>

      <footer
        class="ia-editor-footer sticky bottom-0 z-30 flex flex-wrap items-center justify-end gap-2 py-4 mt-auto border-t border-slate-100 dark:border-slate-800 bg-white/95 dark:bg-slate-900/95 backdrop-blur-sm"
      >
        <router-link :to="{ name: 'settings_ia' }">
          <woot-button variant="smooth" color-scheme="secondary">
            {{ $t('AI_ATTENDANT.FORM.CANCEL') }}
          </woot-button>
        </router-link>
        <woot-button
          v-if="isEdit"
          variant="smooth"
          color-scheme="secondary"
          :is-loading="isSaving"
          :disabled="isSaving"
          @click.prevent="openTestPopup"
        >
          {{ $t('AI_ATTENDANT.TEST.TITLE') }}
        </woot-button>
        <woot-button :is-loading="isSaving" type="submit">
          {{ $t('AI_ATTENDANT.FORM.SUBMIT') }}
        </woot-button>
      </footer>
    </form>

    <AiAttendantTestModal
      :show.sync="showTestPopup"
      :config-id="configId"
      :agent-name="testAgentName"
      :inbox-name="testInboxName"
      :avatar-url="testAvatarUrl"
      @close="closeTestPopup"
    />
    <AiAttendantHandoffModal
      :show.sync="showHandoffModal"
      :value="form.handoff_conditions"
      @apply="applyHandoffConditions"
    />
  </div>
</template>

<style scoped lang="scss">
.ia-editor-tabs {
  @apply -mb-px;
}

.ia-field-label {
  @apply text-slate-800 dark:text-slate-200 block m-0 leading-7 text-sm font-medium;
}

.ia-identity-setup :deep(.ia-avatar-picker__photo) {
  width: 64px;
  height: 64px;
}

.ia-agent-name-input :deep(input) {
  box-sizing: border-box;
  height: 40px;
  min-height: 40px;
  margin-bottom: 0 !important;
  padding: 6px 12px;
  border-radius: 12px;
  font-size: 14px;
  line-height: 1.25;
}

.ia-inbox-multiselect :deep(.multiselect) {
  margin-bottom: 0 !important;
  min-height: 0 !important;
  font-size: 14px;
}

.ia-inbox-multiselect :deep(.multiselect__tags) {
  box-sizing: border-box;
  display: flex;
  align-items: center;
  min-height: 40px !important;
  height: auto !important;
  margin: 0;
  padding: 6px 2.25rem 6px 12px;
  border-radius: 12px;
  border: 1px solid rgb(226 232 240);
  background: #fff;
}

.dark .ia-inbox-multiselect :deep(.multiselect__tags) {
  border-color: rgb(71 85 105);
  background: rgb(15 23 42);
}

.ia-inbox-multiselect :deep(.multiselect__select) {
  height: 100% !important;
  top: 0;
  width: 2.25rem;
}

.ia-inbox-multiselect :deep(.multiselect__select::before) {
  top: 50%;
  margin-top: 0;
  transform: translateY(-50%);
}

.ia-inbox-multiselect :deep(.multiselect__tags-wrap) {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  max-width: 100%;
  margin-top: 0;
}

.ia-inbox-multiselect :deep(.multiselect__tag) {
  margin: 0;
  padding: 2px 22px 2px 8px;
  font-size: 12px;
  line-height: 1.25;
  flex-shrink: 0;
}

.ia-inbox-multiselect :deep(.multiselect__placeholder),
.ia-inbox-multiselect :deep(.multiselect__input) {
  margin: 0;
  padding: 0;
  height: auto;
  min-height: 0;
  font-size: 14px;
  line-height: 1.25;
}

.ia-inbox-multiselect :deep(.multiselect__placeholder) {
  padding-top: 0;
}

.ia-editor-footer {
  box-shadow: 0 -4px 16px rgba(15, 23, 42, 0.06);
}

.dark .ia-editor-footer {
  box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.25);
}
</style>
