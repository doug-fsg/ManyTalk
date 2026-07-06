<script>
import axios from 'axios';
import AccountFormCard from 'shared/components/AccountFormCard.vue';
import {
  resolveFieldValueKey,
  isCheckboxField,
  enrichDefinitionFields,
} from 'shared/helpers/formFieldHelpers';
import { normalizeFieldValueForSubmit } from 'shared/helpers/formFieldMasks';
import {
  publicFormMessages,
  publicFormFieldLabels,
  resolvePublicFormLocale,
} from './messages';
import {
  DEFAULT_FORM_BRANDING,
  resolveFormBranding,
} from 'shared/helpers/formBrandingHelpers';

export default {
  name: 'PublicFormApp',
  components: { AccountFormCard },
  data() {
    return {
      loading: true,
      submitting: false,
      error: null,
      successMessage: null,
      form: null,
      values: {},
    };
  },
  computed: {
    config() {
      return window.publicFormConfig || {};
    },
    locale() {
      return resolvePublicFormLocale(this.config);
    },
    messages() {
      return publicFormMessages(this.locale);
    },
    fieldLabels() {
      return {
        ...publicFormFieldLabels(this.locale),
        defaultTitle: this.form?.name || '',
      };
    },
    pageStyle() {
      const branding = this.form?.branding || DEFAULT_FORM_BRANDING;
      return resolveFormBranding(branding).pageStyle;
    },
    isPaused() {
      return this.config.status === 'paused';
    },

    fields() {
      const m = this.messages;
      const rawFields = this.form?.definition?.fields || [
        { key: 'name', type: 'native', field: 'name', label: m.NATIVE.NAME, required: true },
        { key: 'email', type: 'native', field: 'email', label: m.NATIVE.EMAIL, required: true },
        {
          key: 'phone_number',
          type: 'native',
          field: 'phone_number',
          label: m.NATIVE.PHONE,
          required: false,
        },
      ];
      return enrichDefinitionFields(rawFields);
    },
    defaultFields() {
      const m = this.messages;
      return [
        { key: 'name', type: 'native', field: 'name', label: m.NATIVE.NAME, required: true },
        { key: 'email', type: 'native', field: 'email', label: m.NATIVE.EMAIL, required: true },
        {
          key: 'phone_number',
          type: 'native',
          field: 'phone_number',
          label: m.NATIVE.PHONE,
          required: false,
        },
      ];
    },
    submitLabel() {
      return this.form?.branding?.submit_label || this.messages.SUBMIT;
    },
  },
  mounted() {
    this.loadForm();
  },
  methods: {
    fieldKey(field) {
      return resolveFieldValueKey(field);
    },
    initValues() {
      this.values = {};
      this.fields.forEach(f => {
        const key = this.fieldKey(f);
        this.values[key] = isCheckboxField(f) ? false : '';
      });
    },
    async loadForm() {
      const { accountId, slug } = this.config;
      try {
        const { data } = await axios.get(
          `/public/api/v1/account_forms/${accountId}/${slug}`
        );
        this.form = data;
        this.initValues();
      } catch (err) {
        const respError = err?.response?.data;
        this.error = respError?.message || respError?.error || this.messages.UNAVAILABLE;
      } finally {
        this.loading = false;
      }
    },
    async onSubmit({ honeypot, values: submittedValues }) {
      if (this.submitting || !this.form) return;
      this.submitting = true;
      this.error = null;
      const { accountId, slug } = this.config;
      const params = new URLSearchParams(window.location.search);
      const formValues = submittedValues || this.values;

      const payload = {};
      this.fields.forEach(field => {
        const key = this.fieldKey(field);
        payload[key] = normalizeFieldValueForSubmit(field, formValues[key]);
      });

      const hasPayload = Object.values(payload).some(value => value !== '');
      if (!hasPayload) {
        this.error = this.messages.EMPTY_SUBMISSION;
        this.submitting = false;
        return;
      }

      try {
        const { data } = await axios.post(
          `/public/api/v1/account_forms/${accountId}/${slug}/submit`,
          {
            ...payload,
            website_token: honeypot,
            utm_source: params.get('utm_source'),
            utm_medium: params.get('utm_medium'),
            utm_campaign: params.get('utm_campaign'),
            utm_term: params.get('utm_term'),
            utm_content: params.get('utm_content'),
          },
          {
            headers: { 'Content-Type': 'application/json' },
          }
        );
        this.successMessage = data.message || this.messages.SUBMIT_SUCCESS;
      } catch (err) {
        const respData = err?.response?.data;
        this.error = respData?.message || respData?.error || this.messages.SUBMIT_ERROR;
      } finally {
        this.submitting = false;
      }
    },
  },
};
</script>

<template>
  <div class="min-h-screen px-4 py-10" :style="pageStyle">
    <div class="max-w-lg mx-auto">

      <div v-if="loading" class="flex flex-col items-center py-20 gap-3 text-slate-400">
        <svg class="animate-spin h-8 w-8" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" aria-hidden="true">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
        </svg>
      </div>

      <div
        v-else-if="isPaused || (error && !form)"
        class="p-8 text-center bg-white border rounded-xl border-slate-200 shadow-sm"
      >
        <svg class="mx-auto mb-4 h-12 w-12 text-amber-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M10 9v6m4-6v6M5.25 6.75A2.25 2.25 0 017.5 4.5h9a2.25 2.25 0 012.25 2.25v10.5A2.25 2.25 0 0116.5 19.5h-9a2.25 2.25 0 01-2.25-2.25V6.75z" />
        </svg>
        <p class="text-slate-600">{{ error || messages.UNAVAILABLE }}</p>
      </div>

      <div
        v-else-if="successMessage"
        class="p-8 text-center bg-white border rounded-xl border-slate-200 shadow-sm"
      >
        <svg class="mx-auto mb-4 h-12 w-12 text-green-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-slate-700 text-base">{{ successMessage }}</p>
      </div>

      <AccountFormCard
        v-else-if="form"
        mode="live"
        :branding="form.branding"
        :definition="form.definition"
        :labels="fieldLabels"
        :default-fields="defaultFields"
        :title-fallback="form.name"
        :submit-label="submitLabel"
        :submitting="submitting"
        :error="error"
        :values="values"
        @update:values="val => (values = val)"
        @submit="onSubmit"
      />
    </div>
  </div>
</template>
