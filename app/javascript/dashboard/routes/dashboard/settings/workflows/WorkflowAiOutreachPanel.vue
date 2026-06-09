<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import {
  AI_OUTREACH_OBJECTIVES,
  AI_OUTREACH_TONES,
  AI_OUTREACH_LANGUAGES,
  composeAiOutreachPrompt,
  getAiOutreachObjectivePrompt,
} from './constants';

const props = defineProps({
  nodeProps: { type: Object, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update-node']);
const { t } = useI18n();

const showAdvanced = ref(false);
const isEditingPrompt = ref(false);

const objectivePreset = computed(
  () => props.nodeProps.objective_preset || 'reengagement'
);
const tonePreset = computed(() => props.nodeProps.tone_preset || 'friendly');
const promptCustomized = computed(
  () => props.nodeProps.prompt_customized === true
);

const previewPrompt = computed(() => {
  if (promptCustomized.value) {
    return props.nodeProps.prompt || '';
  }
  return composeAiOutreachPrompt(objectivePreset.value, tonePreset.value);
});

const updateFields = patch => emit('update-node', patch);

const selectObjective = key => {
  if (props.readOnly) return;
  if (promptCustomized.value) {
    updateFields({ objective_preset: key });
    return;
  }
  updateFields({
    objective_preset: key,
    prompt: getAiOutreachObjectivePrompt(key),
    prompt_customized: false,
  });
};

const selectTone = key => {
  if (props.readOnly) return;
  updateFields({
    tone_preset: key,
    prompt_customized: promptCustomized.value,
  });
};

const onLanguageChange = value => {
  updateFields({ language: value });
};

const startEditingPrompt = () => {
  if (props.readOnly) return;
  isEditingPrompt.value = true;
  updateFields({
    prompt_customized: true,
    prompt:
      props.nodeProps.prompt ||
      getAiOutreachObjectivePrompt(objectivePreset.value),
  });
};

const onPromptInput = value => {
  updateFields({ prompt: value, prompt_customized: true });
};

const restoreSuggestedPrompt = () => {
  if (props.readOnly) return;
  isEditingPrompt.value = false;
  updateFields({
    prompt_customized: false,
    prompt: getAiOutreachObjectivePrompt(objectivePreset.value),
  });
};

const inputClass =
  'w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500/30 disabled:opacity-50';
const labelClass =
  'block text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider mb-1.5';
</script>

<template>
  <div class="space-y-5">
    <div>
      <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.AI_OBJECTIVE_LABEL') }}</label>
      <div class="grid grid-cols-2 gap-2">
        <button
          v-for="objective in AI_OUTREACH_OBJECTIVES"
          :key="objective.key"
          type="button"
          :disabled="readOnly"
          class="cursor-pointer text-left px-3 py-2.5 rounded-lg border text-xs font-medium transition-colors duration-150"
          :class="
            objectivePreset === objective.key
              ? 'border-violet-500 bg-violet-50 dark:bg-violet-950/40 text-violet-700 dark:text-violet-200'
              : 'border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:border-violet-300 dark:hover:border-violet-700'
          "
          @click="selectObjective(objective.key)"
        >
          {{ $t(objective.labelKey) }}
        </button>
      </div>
    </div>

    <div>
      <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.AI_TONE_LABEL') }}</label>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="tone in AI_OUTREACH_TONES"
          :key="tone.key"
          type="button"
          :disabled="readOnly"
          class="cursor-pointer px-3 py-1.5 rounded-full border text-xs font-medium transition-colors duration-150"
          :class="
            tonePreset === tone.key
              ? 'border-violet-500 bg-violet-500 text-white'
              : 'border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:border-violet-300 dark:hover:border-violet-700'
          "
          @click="selectTone(tone.key)"
        >
          {{ $t(tone.labelKey) }}
        </button>
      </div>
    </div>

    <div
      class="rounded-lg border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50 p-3 transition-colors duration-150"
      :class="{
        'ring-2 ring-violet-500/30 border-violet-300 dark:border-violet-700':
          isEditingPrompt || promptCustomized,
      }"
    >
      <div class="flex items-start justify-between gap-2 mb-2">
        <p class="text-xs font-semibold text-slate-600 dark:text-slate-400">
          {{ $t('WORKFLOW.EDITOR.AI_PREVIEW_LABEL') }}
        </p>
        <button
          v-if="!isEditingPrompt && !promptCustomized"
          type="button"
          :disabled="readOnly"
          class="cursor-pointer inline-flex items-center gap-1 text-xs font-medium text-violet-600 dark:text-violet-400 hover:text-violet-700 dark:hover:text-violet-300 transition-colors duration-150 shrink-0"
          @click="startEditingPrompt"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
            />
          </svg>
          {{ $t('WORKFLOW.EDITOR.AI_EDIT_PROMPT') }}
        </button>
      </div>

      <template v-if="isEditingPrompt || promptCustomized">
        <input
          type="text"
          maxlength="160"
          :value="nodeProps.prompt || ''"
          :disabled="readOnly"
          :class="inputClass + ' bg-white dark:bg-slate-900'"
          :placeholder="$t('WORKFLOW.EDITOR.AI_PROMPT_PLACEHOLDER')"
          @input="onPromptInput($event.target.value)"
        />
        <button
          v-if="!readOnly"
          type="button"
          class="cursor-pointer mt-2 text-xs text-slate-500 dark:text-slate-400 hover:text-violet-600 dark:hover:text-violet-400 transition-colors duration-150"
          @click="restoreSuggestedPrompt"
        >
          {{ $t('WORKFLOW.EDITOR.AI_RESTORE_SUGGESTION') }}
        </button>
      </template>
      <p
        v-else
        class="text-sm text-slate-800 dark:text-slate-100 leading-snug cursor-pointer"
        @click="startEditingPrompt"
      >
        {{ previewPrompt }}
      </p>
    </div>

    <div class="border-t border-slate-200 dark:border-slate-700 pt-3">
      <button
        type="button"
        class="cursor-pointer flex items-center justify-between w-full text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider"
        @click="showAdvanced = !showAdvanced"
      >
        <span>{{ $t('WORKFLOW.EDITOR.AI_ADVANCED') }}</span>
        <svg
          class="w-4 h-4 transition-transform duration-150"
          :class="{ 'rotate-180': showAdvanced }"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <div v-if="showAdvanced" class="mt-4">
        <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.AI_LANGUAGE_LABEL') }}</label>
        <select
          :value="nodeProps.language || 'client'"
          :disabled="readOnly"
          :class="inputClass"
          @change="onLanguageChange($event.target.value)"
        >
          <option
            v-for="lang in AI_OUTREACH_LANGUAGES"
            :key="lang.key"
            :value="lang.key"
          >
            {{ $t(lang.labelKey) }}
          </option>
        </select>
      </div>
    </div>
  </div>
</template>
