<script setup>
import { computed, nextTick, ref } from 'vue';
import VariableList from 'dashboard/components/widgets/conversation/VariableList.vue';

const props = defineProps({
  // Vue 2 native v-model uses `value` + `input`.
  value: { type: String, default: undefined },
  // Vue 3 / 2.7 compatible alias.
  modelValue: { type: String, default: undefined },
  disabled: { type: Boolean, default: false },
  placeholder: { type: String, default: '' },
  inputClass: { type: String, default: '' },
  hint: { type: String, default: '' },
});

const emit = defineEmits(['input', 'update:modelValue', 'update:model-value']);

const textareaRef = ref(null);
const showVariables = ref(false);
const variableSearchTerm = ref('');
const triggerStart = ref(-1);

const currentValue = computed(() => {
  if (props.value !== undefined && props.value !== null) return String(props.value);
  if (props.modelValue !== undefined && props.modelValue !== null) {
    return String(props.modelValue);
  }
  return '';
});

const emitValue = value => {
  // Vue 2: browsers lower-case custom events; prefer `input` for reliability.
  emit('input', value);
  emit('update:modelValue', value);
  emit('update:model-value', value);
};

const detectVariableTrigger = (value, cursor) => {
  if (cursor == null || cursor < 0) return null;

  const before = value.slice(0, cursor);
  // Trigger on "{" or "{{" so both open the picker.
  const match = before.match(/\{\{?([a-z0-9_.]*)$/i);
  if (!match) return null;

  return {
    start: cursor - match[0].length,
    search: match[1] || '',
  };
};

const onInput = event => {
  const value = event.target.value;
  const cursor = event.target.selectionStart;
  emitValue(value);

  const trigger = detectVariableTrigger(value, cursor);
  if (!trigger) {
    showVariables.value = false;
    variableSearchTerm.value = '';
    triggerStart.value = -1;
    return;
  }

  showVariables.value = true;
  variableSearchTerm.value = trigger.search;
  triggerStart.value = trigger.start;
};

const onBlur = () => {
  // Allow click on VariableList before closing.
  window.setTimeout(() => {
    showVariables.value = false;
    variableSearchTerm.value = '';
    triggerStart.value = -1;
  }, 150);
};

const insertVariable = async variableKey => {
  const textarea = textareaRef.value;
  if (!textarea || triggerStart.value < 0) return;

  const value = currentValue.value || '';
  const cursor = textarea.selectionStart != null ? textarea.selectionStart : value.length;
  const insertion = `{{${variableKey}}}`;
  const nextValue = `${value.slice(0, triggerStart.value)}${insertion}${value.slice(cursor)}`;
  const nextCursor = triggerStart.value + insertion.length;

  emitValue(nextValue);
  showVariables.value = false;
  variableSearchTerm.value = '';
  triggerStart.value = -1;

  await nextTick();
  textarea.focus();
  textarea.setSelectionRange(nextCursor, nextCursor);
};
</script>

<template>
  <div class="relative space-y-1.5">
    <div class="relative z-0">
      <textarea
        ref="textareaRef"
        :value="currentValue"
        :disabled="disabled"
        :class="inputClass"
        :placeholder="placeholder"
        name="workflow-message"
        autocomplete="off"
        @input="onInput"
        @blur="onBlur"
      />
      <div
        v-if="showVariables && !disabled"
        class="workflow-var-picker absolute left-0 right-0 bottom-full z-50 mb-1"
      >
        <VariableList
          :search-key="variableSearchTerm"
          @click="insertVariable"
        />
      </div>
    </div>
    <p v-if="hint" class="text-xs text-slate-500 dark:text-slate-400">
      {{ hint }}
    </p>
  </div>
</template>

<style scoped>
.workflow-var-picker :deep(.mention--box) {
  position: static;
  width: 100%;
  max-height: 9.75rem;
  overflow: auto;
  z-index: auto;
}
</style>
