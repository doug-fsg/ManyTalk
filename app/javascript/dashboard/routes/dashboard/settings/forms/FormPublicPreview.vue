<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import AccountFormCard from 'shared/components/AccountFormCard.vue';
import { resolveFormBranding } from 'shared/helpers/formBrandingHelpers';

const props = defineProps({
  branding: { type: Object, required: true },
  settings: { type: Object, default: () => ({}) },
  definition: { type: Object, default: () => ({ fields: [] }) },
  contactAttributes: { type: Array, default: () => [] },
  isMobile: { type: Boolean, default: false },
});

const { t } = useI18n();

const resolved = computed(() => resolveFormBranding(props.branding));

const fieldLabels = computed(() => ({
  defaultTitle: t('ACCOUNT_FORM.PREVIEW.DEFAULT_TITLE'),
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

const defaultFields = computed(() => [
  {
    key: 'name',
    type: 'native',
    field: 'name',
    label: t('ACCOUNT_FORM.NATIVE.NAME'),
    required: true,
  },
  {
    key: 'email',
    type: 'native',
    field: 'email',
    label: t('ACCOUNT_FORM.NATIVE.EMAIL'),
    required: true,
  },
  {
    key: 'phone_number',
    type: 'native',
    field: 'phone_number',
    label: t('ACCOUNT_FORM.NATIVE.PHONE'),
    required: false,
  },
]);
</script>

<template>
  <div
    class="p-4"
    :class="isMobile ? 'min-h-full' : ''"
    :style="resolved.pageStyle"
  >
    <AccountFormCard
      mode="preview"
      :branding="branding"
      :definition="definition"
      :contact-attributes="contactAttributes"
      :labels="fieldLabels"
      :default-fields="defaultFields"
      :is-mobile="isMobile"
      :submit-label="$t('ACCOUNT_FORM.PREVIEW.SUBMIT')"
      :title-fallback="$t('ACCOUNT_FORM.PREVIEW.DEFAULT_TITLE')"
    />
  </div>
</template>
