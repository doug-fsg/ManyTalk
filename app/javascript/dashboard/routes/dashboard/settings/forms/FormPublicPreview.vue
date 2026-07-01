<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import FormPublicFieldInput from 'shared/components/FormPublicFieldInput.vue';
import { isCheckboxField, enrichDefinitionFields } from 'shared/helpers/formFieldHelpers';

const props = defineProps({
  branding: { type: Object, required: true },
  settings: { type: Object, default: () => ({}) },
  definition: { type: Object, default: () => ({ fields: [] }) },
  contactAttributes: { type: Array, default: () => [] },
  isMobile: { type: Boolean, default: false },
});

const { t } = useI18n();

const primaryColor = computed(() => props.branding?.primary_color || '#1f93ff');

const fields = computed(() => {
  const rawFields = props.definition?.fields?.length
    ? props.definition.fields
    : [
        { key: 'name', type: 'native', field: 'name', label: t('ACCOUNT_FORM.NATIVE.NAME'), required: true },
        { key: 'email', type: 'native', field: 'email', label: t('ACCOUNT_FORM.NATIVE.EMAIL'), required: true },
        {
          key: 'phone_number',
          type: 'native',
          field: 'phone_number',
          label: t('ACCOUNT_FORM.NATIVE.PHONE'),
          required: false,
        },
      ];
  return enrichDefinitionFields(rawFields, props.contactAttributes);
});

const previewInputClass =
  'w-full px-3 py-2 text-xs text-slate-400 dark:text-slate-500 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg outline-none';

const previewSelectClass = `${previewInputClass} text-slate-400`;

const fieldLabel = field => field.label || '';

const fieldLabels = computed(() => ({
  selectRequired: t('ACCOUNT_FORM.PUBLIC_FIELD.SELECT_REQUIRED'),
  selectOptional: t('ACCOUNT_FORM.PUBLIC_FIELD.SELECT_OPTIONAL'),
  noListOptions: t('ACCOUNT_FORM.PUBLIC_FIELD.NO_LIST_OPTIONS'),
  placeholders: {
    phone: t('ACCOUNT_FORM.PUBLIC_FIELD.PLACEHOLDER_PHONE'),
    email: t('ACCOUNT_FORM.PUBLIC_FIELD.PLACEHOLDER_EMAIL'),
    name: t('ACCOUNT_FORM.PUBLIC_FIELD.PLACEHOLDER_NAME'),
    link: t('ACCOUNT_FORM.PUBLIC_FIELD.PLACEHOLDER_LINK'),
    currency: t('ACCOUNT_FORM.PUBLIC_FIELD.PLACEHOLDER_CURRENCY'),
    percent: t('ACCOUNT_FORM.PUBLIC_FIELD.PLACEHOLDER_PERCENT'),
    number: t('ACCOUNT_FORM.PUBLIC_FIELD.PLACEHOLDER_NUMBER'),
  },
}));
</script>

<template>
  <div
    class="flex flex-col bg-white dark:bg-slate-900 rounded-xl overflow-hidden pointer-events-none select-none"
    :class="isMobile ? 'text-sm' : ''"
  >
    <div
      class="px-5 pt-5 pb-4"
      :style="{ borderBottom: '1px solid #f1f5f9' }"
    >
      <img
        v-if="branding.logo_url"
        :src="branding.logo_url"
        alt=""
        class="h-8 max-w-[120px] object-contain mb-3 mx-auto block"
      />
      <h2
        class="font-semibold text-slate-900 dark:text-slate-50 leading-tight"
        :class="isMobile ? 'text-base' : 'text-lg'"
      >
        {{ branding.header_title || $t('ACCOUNT_FORM.PREVIEW.DEFAULT_TITLE') }}
      </h2>
      <p
        v-if="branding.header_description"
        class="mt-1 text-xs text-slate-500 dark:text-slate-400 leading-relaxed"
      >
        {{ branding.header_description }}
      </p>
    </div>

    <div class="px-5 py-4 flex flex-col gap-3.5">
      <div v-for="field in fields" :key="field.key">
        <label
          v-if="!isCheckboxField(field)"
          class="block mb-1 text-xs font-medium text-slate-700 dark:text-slate-300"
        >
          {{ fieldLabel(field) }}
          <span
            v-if="field.required"
            class="ml-0.5 text-red-400"
            aria-hidden="true"
          >*</span>
        </label>
        <FormPublicFieldInput
          :field="field"
          :model-value="isCheckboxField(field) ? false : ''"
          readonly
          :labels="fieldLabels"
          :input-class="previewInputClass"
          :select-class="previewSelectClass"
          checkbox-class="pointer-events-none opacity-80"
        />
      </div>
    </div>

    <div class="px-5 pb-5">
      <button
        type="button"
        class="w-full py-2 text-xs font-medium text-white rounded-lg transition-opacity"
        :style="{ backgroundColor: primaryColor }"
        tabindex="-1"
      >
        {{ $t('ACCOUNT_FORM.PREVIEW.SUBMIT') }}
      </button>
    </div>
  </div>
</template>
