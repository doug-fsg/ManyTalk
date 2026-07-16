<script setup>
import { computed, ref } from 'vue';
import FormPublicFieldInput from 'shared/components/FormPublicFieldInput.vue';
import {
  resolveFieldValueKey,
  isCheckboxField,
  enrichDefinitionFields,
} from 'shared/helpers/formFieldHelpers';
import { resolveFormBranding } from 'shared/helpers/formBrandingHelpers';

const props = defineProps({
  branding: { type: Object, default: () => ({}) },
  definition: { type: Object, default: () => ({ fields: [] }) },
  contactAttributes: { type: Array, default: () => [] },
  mode: { type: String, default: 'live' },
  labels: { type: Object, default: () => ({}) },
  titleFallback: { type: String, default: '' },
  submitLabel: { type: String, default: 'Enviar' },
  submitting: { type: Boolean, default: false },
  error: { type: String, default: '' },
  values: { type: Object, default: () => ({}) },
  isMobile: { type: Boolean, default: false },
  defaultFields: { type: Array, default: () => [] },
});

const emit = defineEmits(['submit', 'update:values']);

const honeypot = ref('');
const isPreview = computed(() => props.mode === 'preview');
const resolved = computed(() => resolveFormBranding(props.branding));

const fields = computed(() => {
  const raw =
    props.definition?.fields?.length > 0
      ? props.definition.fields
      : props.defaultFields;
  return enrichDefinitionFields(raw || [], props.contactAttributes);
});

const title = computed(
  () =>
    props.branding?.header_title ||
    props.titleFallback ||
    props.labels.defaultTitle ||
    ''
);

const fieldKey = field => resolveFieldValueKey(field);

const fieldValue = field => {
  if (isPreview.value) {
    return isCheckboxField(field) ? false : '';
  }
  const key = fieldKey(field);
  if (Object.prototype.hasOwnProperty.call(props.values, key)) {
    return props.values[key];
  }
  return isCheckboxField(field) ? false : '';
};

const updateField = (field, val) => {
  if (isPreview.value) return;
  const key = fieldKey(field);
  emit('update:values', { ...props.values, [key]: val });
};

const inputClass = computed(() => {
  const base = resolved.value.inputClass;
  if (isPreview.value) {
    return `${base} text-xs text-slate-400`;
  }
  return base;
});

const textareaClass = computed(() => {
  const base = resolved.value.textareaClass;
  if (isPreview.value) {
    return `${base} text-xs text-slate-400`;
  }
  return base;
});

const selectClass = computed(() => {
  const base = resolved.value.selectClass;
  if (isPreview.value) {
    return `${base} text-xs text-slate-400`;
  }
  return base;
});

const formRef = ref(null);

const readFieldValuesFromDom = () => {
  if (!formRef.value) return {};

  const domValues = {};
  formRef.value
    .querySelectorAll('input[id^="field-"], select[id^="field-"], textarea[id^="field-"]')
    .forEach(el => {
      const key = el.id.replace(/^field-/, '');
      if (!key) return;

      domValues[key] = el.type === 'checkbox' ? el.checked : el.value;
    });

  return domValues;
};

const onSubmit = () => {
  if (isPreview.value || props.submitting) return;

  const mergedValues = { ...props.values, ...readFieldValuesFromDom() };
  emit('submit', { honeypot: honeypot.value, values: mergedValues });
};
</script>

<template>
  <form
    ref="formRef"
    class="overflow-hidden border shadow-sm rounded-xl"
    :class="[
      isPreview ? 'pointer-events-none select-none' : '',
      isMobile ? 'text-sm' : '',
    ]"
    :style="{
      ...resolved.cardStyle,
      '--tw-ring-color': resolved.primaryColor,
    }"
    @submit.prevent="onSubmit"
  >
    <!-- Expanded logo banner -->
    <div
      v-if="resolved.logoUrl && resolved.logoExpand"
      class="w-full overflow-hidden"
      :style="{ maxHeight: isPreview ? '112px' : '140px' }"
    >
      <img
        :src="resolved.logoUrl"
        alt=""
        class="object-cover object-center w-full"
        :style="{ height: isPreview ? '96px' : '120px' }"
      />
    </div>

    <div
      class="px-5 pt-5 pb-4"
      :class="{ 'px-6 pt-6': !isPreview }"
      :style="resolved.headerBorderStyle"
    >
      <!-- Normal logo -->
      <div
        v-if="resolved.logoUrl && !resolved.logoExpand"
        class="flex mb-3"
        :class="[resolved.logoJustifyClass, isPreview ? '' : 'mb-4']"
      >
        <img
          :src="resolved.logoUrl"
          alt=""
          class="object-contain"
          :class="
            isPreview ? 'h-8 max-w-[120px]' : 'h-10 max-w-[160px]'
          "
        />
      </div>

      <component
        :is="isPreview ? 'h2' : 'h1'"
        class="font-semibold leading-tight"
        :class="
          isPreview
            ? isMobile
              ? 'text-base'
              : 'text-lg'
            : 'text-xl'
        "
        :style="resolved.titleStyle"
      >
        {{ title }}
      </component>
      <p
        v-if="branding.header_description"
        class="mt-1 leading-relaxed"
        :class="isPreview ? 'text-xs' : 'mb-0 text-sm'"
        :style="resolved.descriptionStyle"
      >
        {{ branding.header_description }}
      </p>
    </div>

    <div
      class="flex flex-col px-5 py-4"
      :class="isPreview ? 'gap-3.5' : 'gap-4 px-6'"
    >
      <div v-for="field in fields" :key="fieldKey(field)">
        <label
          v-if="!isCheckboxField(field)"
          class="block mb-1 font-medium"
          :class="isPreview ? 'text-xs' : 'text-sm'"
          :style="resolved.labelStyle"
        >
          {{ field.label || '' }}
          <span
            v-if="field.required"
            class="ml-0.5 text-red-500"
            aria-hidden="true"
          >*</span>
        </label>
        <FormPublicFieldInput
          :field="field"
          :model-value="fieldValue(field)"
          :readonly="isPreview"
          :labels="labels"
          :input-class="inputClass"
          :textarea-class="textareaClass"
          :select-class="selectClass"
          :checkbox-class="isPreview ? 'pointer-events-none opacity-80' : ''"
          @update:model-value="val => updateField(field, val)"
        />
      </div>

      <template v-if="!isPreview">
        <input
          v-model="honeypot"
          type="text"
          name="website_token"
          tabindex="-1"
          autocomplete="off"
          class="hidden"
          aria-hidden="true"
        />

        <div
          v-if="error"
          class="flex items-center gap-1.5 text-sm text-red-600"
          role="alert"
        >
          <svg
            class="h-4 w-4 shrink-0"
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
              d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          {{ error }}
        </div>
      </template>
    </div>

    <div class="px-5 pb-5" :class="{ 'px-6 pb-6': !isPreview }">
      <button
        :type="isPreview ? 'button' : 'submit'"
        class="flex items-center justify-center w-full gap-2 text-sm font-medium text-white transition-opacity rounded-lg disabled:opacity-60"
        :class="isPreview ? 'py-2 text-xs' : 'px-4 py-2.5 min-h-[44px]'"
        :style="resolved.buttonStyle"
        :tabindex="isPreview ? -1 : 0"
        :disabled="!isPreview && submitting"
      >
        <svg
          v-if="!isPreview && submitting"
          class="w-4 h-4 animate-spin"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <circle
            class="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            stroke-width="4"
          />
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
          />
        </svg>
        {{ isPreview || !submitting ? submitLabel : '' }}
      </button>
    </div>
  </form>
</template>
