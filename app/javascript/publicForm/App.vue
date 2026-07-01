<script>
import axios from 'axios';
import FormPublicFieldInput from 'shared/components/FormPublicFieldInput.vue';
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

export default {
  name: 'PublicFormApp',
  components: { FormPublicFieldInput },
  data() {
    return {
      loading: true,
      submitting: false,
      error: null,
      successMessage: null,
      form: null,
      values: {},
      honeypot: '',
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
      return publicFormFieldLabels(this.locale);
    },
    primaryColor() {
      return this.form?.branding?.primary_color || '#1f93ff';
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
    submitLabel() {
      return this.form?.branding?.submit_label || this.messages.SUBMIT;
    },
  },
  mounted() {
    this.loadForm();
  },
  methods: {
    isCheckboxField,
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
    async submitForm() {
      if (this.submitting || !this.form) return;
      this.submitting = true;
      this.error = null;
      const { accountId, slug } = this.config;
      const params = new URLSearchParams(window.location.search);

      const payload = {};
      this.fields.forEach(field => {
        const key = this.fieldKey(field);
        payload[key] = normalizeFieldValueForSubmit(field, this.values[key]);
      });

      try {
        const { data } = await axios.post(
          `/public/api/v1/account_forms/${accountId}/${slug}/submit`,
          {
            ...payload,
            website_token: this.honeypot,
            utm_source: params.get('utm_source'),
            utm_medium: params.get('utm_medium'),
            utm_campaign: params.get('utm_campaign'),
            utm_term: params.get('utm_term'),
            utm_content: params.get('utm_content'),
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
  <div class="min-h-screen px-4 py-10 bg-slate-50">
    <div class="max-w-lg mx-auto">
      <!-- Loading -->
      <div v-if="loading" class="flex flex-col items-center py-20 gap-3 text-slate-400">
        <svg class="animate-spin h-8 w-8" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" aria-hidden="true">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
        </svg>
      </div>

      <!-- Unavailable / Paused -->
      <div
        v-else-if="isPaused || (error && !form)"
        class="p-8 text-center bg-white border rounded-xl border-slate-200 shadow-sm"
      >
        <svg class="mx-auto mb-4 h-12 w-12 text-amber-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M10 9v6m4-6v6M5.25 6.75A2.25 2.25 0 017.5 4.5h9a2.25 2.25 0 012.25 2.25v10.5A2.25 2.25 0 0116.5 19.5h-9a2.25 2.25 0 01-2.25-2.25V6.75z" />
        </svg>
        <p class="text-slate-600">{{ error || messages.UNAVAILABLE }}</p>
      </div>

      <!-- Success -->
      <div
        v-else-if="successMessage"
        class="p-8 text-center bg-white border rounded-xl border-slate-200 shadow-sm"
      >
        <svg class="mx-auto mb-4 h-12 w-12 text-green-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-slate-700 text-base">{{ successMessage }}</p>
      </div>

      <!-- Form -->
      <form
        v-else-if="form"
        class="p-6 bg-white border rounded-xl border-slate-200 shadow-sm"
        @submit.prevent="submitForm"
      >
        <div
          v-if="form.branding && form.branding.logo_url"
          class="flex justify-center mb-4"
        >
          <img
            :src="form.branding.logo_url"
            alt=""
            class="object-contain h-10 max-w-[160px]"
          />
        </div>
        <h1 class="text-xl font-semibold text-slate-900">
          {{ (form.branding && form.branding.header_title) || form.name }}
        </h1>
        <p
          v-if="form.branding && form.branding.header_description"
          class="mt-1 mb-6 text-sm text-slate-500"
        >
          {{ form.branding.header_description }}
        </p>
        <div v-else class="mb-6" />

        <div class="space-y-4">
          <div
            v-for="field in fields"
            :key="fieldKey(field)"
            class="block text-sm"
          >
            <span
              v-if="!isCheckboxField(field)"
              class="mb-1 block text-slate-700"
            >
              {{ field.label }}<span v-if="field.required" class="ml-0.5 text-red-500" aria-hidden="true">*</span>
            </span>
            <FormPublicFieldInput
              :field="field"
              :model-value="values[fieldKey(field)]"
              :labels="fieldLabels"
              input-class="w-full px-3 py-2 border rounded-lg border-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-0 transition-shadow"
              select-class="w-full px-3 py-2 border rounded-lg border-slate-200 bg-white text-slate-900 focus:outline-none focus:ring-2 focus:ring-offset-0 transition-shadow"
              @update:model-value="val => (values[fieldKey(field)] = val)"
            />
          </div>

          <!-- Honeypot (hidden) -->
          <input
            v-model="honeypot"
            type="text"
            name="website_token"
            tabindex="-1"
            autocomplete="off"
            class="hidden"
            aria-hidden="true"
          />
        </div>

        <!-- Error -->
        <div v-if="error" class="flex items-center gap-1.5 mt-3 text-sm text-red-600" role="alert">
          <svg class="h-4 w-4 shrink-0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          {{ error }}
        </div>

        <!-- Submit -->
        <button
          type="submit"
          class="relative w-full px-4 py-2.5 mt-6 text-sm font-medium text-white rounded-lg transition-opacity disabled:opacity-60 flex items-center justify-center gap-2"
          :style="{ backgroundColor: primaryColor }"
          :disabled="submitting"
        >
          <svg v-if="submitting" class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" aria-hidden="true">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          {{ submitting ? '' : submitLabel }}
        </button>
      </form>
    </div>
  </div>
</template>
