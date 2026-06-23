<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import {
  findWorkflowIntentByKey,
  searchWorkflowIntents,
} from './constants';

const WAIT_UNITS = [
  { key: 'minutes', labelKey: 'WORKFLOW.EDITOR.MINUTES' },
  { key: 'hours', labelKey: 'WORKFLOW.EDITOR.HOURS' },
  { key: 'days', labelKey: 'WORKFLOW.EDITOR.DAYS' },
];

const props = defineProps({
  nodeProps: { type: Object, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update-node']);
const { t } = useI18n();

const searchQuery = ref('');
const showSuggestions = ref(false);

const hasWebhookUrl = computed(
  () =>
    typeof window !== 'undefined' &&
    window.__WORKFLOW_AI_INTENT_CONFIGURED__ === true
);

const selectedIntent = computed(() =>
  props.nodeProps.intent_key
    ? findWorkflowIntentByKey(props.nodeProps.intent_key)
    : null
);

const duration = computed(() => {
  const value = props.nodeProps.duration;
  return value != null && value !== '' ? value : 30;
});
const unit = computed(() => props.nodeProps.unit || 'minutes');
const intentDescription = computed(
  () => props.nodeProps.intent_description || ''
);

const suggestions = computed(() => searchWorkflowIntents(searchQuery.value, 8));

const hasSelection = computed(() => Boolean(props.nodeProps.intent_key));

const descriptionPlaceholder = computed(() => {
  const intent = selectedIntent.value;
  if (intent && intent.description) return intent.description;
  return t('WORKFLOW.EDITOR.INTENT_DESCRIPTION_PLACEHOLDER');
});

const searchInputBorderClass = computed(() =>
  hasSelection.value
    ? 'border-violet-400 dark:border-violet-500'
    : 'border-slate-200 dark:border-slate-600'
);

const isIntentSelected = intent =>
  intent.key === props.nodeProps.intent_key;

watch(
  () => props.nodeProps.intent_key,
  key => {
    if (key && selectedIntent.value) {
      searchQuery.value = selectedIntent.value.label;
    } else if (!key) {
      searchQuery.value = '';
    }
  },
  { immediate: true }
);

const onSearchFocus = () => {
  if (props.readOnly) return;
  showSuggestions.value = true;
};

const onSearchInput = event => {
  searchQuery.value = event.target.value;
  showSuggestions.value = true;
  if (
    selectedIntent.value &&
    searchQuery.value !== selectedIntent.value.label
  ) {
    emit('update-node', { intent_key: '', intent_description: '' });
  }
};

const selectIntent = intent => {
  if (props.readOnly) return;
  emit('update-node', {
    intent_key: intent.key,
    intent_description: props.nodeProps.intent_description || '',
  });
  searchQuery.value = intent.label;
  showSuggestions.value = false;
};

const clearSelection = () => {
  if (props.readOnly) return;
  emit('update-node', { intent_key: '', intent_description: '' });
  searchQuery.value = '';
  showSuggestions.value = true;
};

const onSearchBlur = () => {
  window.setTimeout(() => {
    showSuggestions.value = false;
  }, 150);
};

const updateDescription = val =>
  emit('update-node', { intent_description: val });

const updateDuration = val => emit('update-node', { duration: Number(val) || 1 });
const updateUnit = val => emit('update-node', { unit: val });
</script>

<template>
  <div class="space-y-4">
    <div
      v-if="!hasWebhookUrl"
      class="flex items-center gap-1.5 p-2 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700"
      :title="t('WORKFLOW.EDITOR.INTENT_WEBHOOK_MISSING_TOOLTIP')"
    >
      <svg
        class="w-3.5 h-3.5 text-amber-500 flex-shrink-0"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
        />
      </svg>
      <span class="text-xs text-amber-700 dark:text-amber-300">
        {{ t('WORKFLOW.EDITOR.INTENT_WEBHOOK_MISSING') }}
      </span>
    </div>

    <!-- Intent search -->
    <div class="relative">
      <label class="text-xs font-medium text-slate-600 dark:text-slate-300 mb-1.5 block">
        {{ t('WORKFLOW.EDITOR.INTENT_LABEL') }}
      </label>
      <div class="relative">
        <span
          class="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
          aria-hidden="true"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
        </span>
        <input
          type="search"
          :value="searchQuery"
          :disabled="readOnly"
          :placeholder="t('WORKFLOW.EDITOR.INTENT_SEARCH_PLACEHOLDER')"
          autocomplete="off"
          class="w-full pl-8 pr-8 py-2 text-sm border rounded-lg bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-violet-400 disabled:opacity-50"
          :class="searchInputBorderClass"
          @focus="onSearchFocus"
          @input="onSearchInput"
          @blur="onSearchBlur"
        />
        <button
          v-if="hasSelection && !readOnly"
          type="button"
          class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
          :title="t('WORKFLOW.EDITOR.INTENT_CLEAR')"
          @mousedown.prevent="clearSelection"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <ul
        v-if="showSuggestions && suggestions.length && !readOnly"
        class="absolute z-20 mt-1 w-full max-h-48 overflow-y-auto rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 shadow-lg"
        role="listbox"
      >
        <li
          v-for="intent in suggestions"
          :key="intent.key"
          role="option"
          class="px-3 py-2 cursor-pointer hover:bg-violet-50 dark:hover:bg-violet-900/20 border-b border-slate-100 dark:border-slate-700 last:border-0"
          :class="{ 'bg-violet-50 dark:bg-violet-900/30': isIntentSelected(intent) }"
          @mousedown.prevent="selectIntent(intent)"
        >
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ intent.label }}
          </span>
          <span class="block text-xs text-slate-500 dark:text-slate-400 truncate">
            {{ intent.description }}
          </span>
        </li>
      </ul>

      <p
        v-if="showSuggestions && !suggestions.length && searchQuery && !readOnly"
        class="absolute z-20 mt-1 w-full px-3 py-2 text-xs text-slate-500 dark:text-slate-400 rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 shadow-lg"
      >
        {{ t('WORKFLOW.EDITOR.INTENT_SEARCH_EMPTY') }}
      </p>

      <p
        v-if="!hasSelection"
        class="mt-1 text-xs text-amber-600 dark:text-amber-400"
      >
        {{ t('WORKFLOW.EDITOR.INTENT_REQUIRED') }}
      </p>
    </div>

    <!-- Optional description (after selection) -->
    <div v-if="hasSelection">
      <label class="text-xs font-medium text-slate-600 dark:text-slate-300 mb-1 block">
        {{ t('WORKFLOW.EDITOR.INTENT_DESCRIPTION_LABEL') }}
      </label>
      <textarea
        :value="intentDescription"
        :disabled="readOnly"
        rows="2"
        maxlength="500"
        :placeholder="descriptionPlaceholder"
        class="w-full px-3 py-2 text-sm border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-violet-400 disabled:opacity-50 resize-none"
        @input="updateDescription($event.target.value)"
      />
      <p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
        {{ t('WORKFLOW.EDITOR.INTENT_DESCRIPTION_HINT') }}
      </p>
    </div>

    <!-- Timeout duration -->
    <div>
      <div class="flex items-center gap-1 mb-1">
        <label class="text-xs font-medium text-slate-600 dark:text-slate-300">
          {{ t('WORKFLOW.EDITOR.WAIT_DURATION_LABEL') }}
        </label>
        <span
          :title="t('WORKFLOW.EDITOR.INTENT_HELP_TOOLTIP')"
          class="cursor-help text-slate-400 text-xs select-none"
        >ⓘ</span>
      </div>
      <div class="flex gap-2">
        <input
          type="number"
          min="1"
          :value="duration"
          :disabled="readOnly"
          class="w-16 px-2 py-1 text-sm border border-slate-200 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-violet-400"
          @input="updateDuration($event.target.value)"
        />
        <select
          :value="unit"
          :disabled="readOnly"
          class="flex-1 px-2 py-1 text-sm border border-slate-200 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-violet-400"
          @change="updateUnit($event.target.value)"
        >
          <option v-for="u in WAIT_UNITS" :key="u.key" :value="u.key">
            {{ t(u.labelKey) }}
          </option>
        </select>
      </div>
    </div>

    <!-- Branch legend -->
    <div class="space-y-1">
      <div
        class="flex items-center gap-2 px-2 py-1.5 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800"
        :title="t('WORKFLOW.EDITOR.BRANCH_INTENT_DETECTED_TTIP')"
      >
        <svg class="w-3.5 h-3.5 text-green-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
        </svg>
        <span class="text-xs text-green-700 dark:text-green-300">
          {{ t('WORKFLOW.EDITOR.BRANCH_INTENT_DETECTED') }}
        </span>
      </div>
      <div
        class="flex items-center gap-2 px-2 py-1.5 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
        :title="t('WORKFLOW.EDITOR.BRANCH_INTENT_TIMEOUT_TTIP')"
      >
        <svg class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ t('WORKFLOW.EDITOR.BRANCH_INTENT_TIMEOUT') }}
        </span>
      </div>
    </div>
  </div>
</template>
