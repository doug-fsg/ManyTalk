<script setup>
import { computed } from 'vue';
import {
  resolveFieldValueKey,
  listOptionsFromField,
  isCheckboxField,
  isListField,
  getFieldKind,
  inputTypeForField,
  inputModeForField,
  fieldPlaceholderForField,
  autocompleteForField,
} from 'shared/helpers/formFieldHelpers';
import { applyFieldInputMask } from 'shared/helpers/formFieldMasks';

const props = defineProps({
  field: { type: Object, required: true },
  modelValue: { type: [String, Number, Boolean], default: '' },
  disabled: { type: Boolean, default: false },
  readonly: { type: Boolean, default: false },
  inputClass: { type: String, default: '' },
  textareaClass: { type: String, default: '' },
  selectClass: { type: String, default: '' },
  checkboxClass: { type: String, default: '' },
  labels: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['update:modelValue']);

const valueKey = computed(() => resolveFieldValueKey(props.field));
const listOptions = computed(() => listOptionsFromField(props.field));
const fieldKind = computed(() => getFieldKind(props.field));
const isCheckbox = computed(() => isCheckboxField(props.field));
const isList = computed(() => isListField(props.field));
const inputType = computed(() => inputTypeForField(props.field));
const inputMode = computed(() => inputModeForField(props.field));
const placeholder = computed(() => {
  const kind = fieldKind.value;
  const custom = props.labels.placeholders?.[kind];
  if (custom) return custom;
  return fieldPlaceholderForField(props.field);
});
const autocomplete = computed(() => autocompleteForField(props.field));

const selectPlaceholder = computed(() =>
  props.field.required
    ? props.labels.selectRequired || 'Selecione uma opção…'
    : props.labels.selectOptional || 'Opcional'
);

const noListOptionsMessage = computed(
  () => props.labels.noListOptions || 'Nenhuma opção configurada para este campo.'
);

const textareaHint = computed(() => props.labels.textareaHint || '');

const resolvedTextareaClass = computed(() =>
  props.textareaClass || props.inputClass
);

const updateValue = val => {
  emit('update:modelValue', val);
};

const handleInput = event => {
  const nextValue = applyFieldInputMask(props.field, event.target.value);
  if (event.target.value !== nextValue) {
    event.target.value = nextValue;
  }
  updateValue(nextValue);
};
</script>

<template>
  <label
    v-if="isCheckbox"
    class="inline-flex items-center gap-2 cursor-pointer"
    :class="checkboxClass"
  >
    <input
      type="checkbox"
      :id="`field-${valueKey}`"
      :name="valueKey"
      :checked="Boolean(modelValue)"
      :disabled="disabled"
      :required="field.required"
      class="rounded border-slate-300 text-woot-500 focus:ring-woot-500"
      @change="updateValue($event.target.checked)"
    />
    <span class="text-sm text-slate-600">{{ field.label }}</span>
  </label>

  <div v-else-if="isList" class="relative">
    <select
      :id="`field-${valueKey}`"
      :name="valueKey"
      :value="modelValue"
      :disabled="disabled || !listOptions.length"
      :required="field.required && listOptions.length > 0"
      :class="[selectClass, 'form-public-select pr-10']"
      @change="updateValue($event.target.value)"
    >
      <option value="" disabled>{{ selectPlaceholder }}</option>
      <option v-for="(option, index) in listOptions" :key="`${option}-${index}`" :value="option">
        {{ option }}
      </option>
    </select>
    <svg
      class="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      aria-hidden="true"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M19 9l-7 7-7-7"
      />
    </svg>
    <p
      v-if="!listOptions.length && !readonly"
      class="mt-1 text-xs text-amber-600"
    >
      {{ noListOptionsMessage }}
    </p>
  </div>

  <div v-else-if="fieldKind === 'currency'" class="relative">
    <span
      class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-slate-500"
      aria-hidden="true"
    >
      R$
    </span>
    <input
      :id="`field-${valueKey}`"
      :name="valueKey"
      :value="modelValue"
      type="text"
      inputmode="decimal"
      :disabled="disabled"
      :readonly="readonly"
      :required="field.required"
      :placeholder="placeholder"
      autocomplete="off"
      :class="[inputClass, 'pl-10']"
      @input="handleInput"
    />
  </div>

  <div v-else-if="fieldKind === 'percent'" class="relative">
    <input
      :id="`field-${valueKey}`"
      :name="valueKey"
      :value="modelValue"
      type="text"
      inputmode="decimal"
      :disabled="disabled"
      :readonly="readonly"
      :required="field.required"
      :placeholder="placeholder"
      autocomplete="off"
      :class="[inputClass, 'pr-9']"
      @input="handleInput"
    />
    <span
      class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-slate-500"
      aria-hidden="true"
    >
      %
    </span>
  </div>

  <div v-else-if="fieldKind === 'textarea'" class="form-public-textarea-wrap">
    <textarea
      :id="`field-${valueKey}`"
      :name="valueKey"
      :value="modelValue"
      rows="5"
      wrap="soft"
      :disabled="disabled"
      :readonly="readonly"
      :required="field.required"
      :placeholder="placeholder"
      :autocomplete="autocomplete"
      :class="[resolvedTextareaClass, 'form-public-textarea']"
      @input="updateValue($event.target.value)"
    />
    <p
      v-if="textareaHint && !readonly"
      class="form-public-textarea-hint mt-1.5 text-xs leading-snug"
    >
      {{ textareaHint }}
    </p>
  </div>

  <input
    v-else
    :id="`field-${valueKey}`"
    :name="valueKey"
    :value="modelValue"
    :type="inputType"
    :inputmode="inputMode || (fieldKind === 'number' ? 'numeric' : undefined)"
    :disabled="disabled"
    :readonly="readonly"
    :required="field.required"
    :placeholder="placeholder"
    :autocomplete="autocomplete"
    :class="inputClass"
    @input="fieldKind === 'phone' || fieldKind === 'number' ? handleInput($event) : updateValue($event.target.value)"
    @change="fieldKind === 'phone' || fieldKind === 'number' ? handleInput($event) : updateValue($event.target.value)"
  />
</template>
