<script>
import axios from 'axios';

export default {
  name: 'PublicFormApp',
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
    primaryColor() {
      return this.form?.branding?.primary_color || '#1f93ff';
    },
    isPaused() {
      return this.config.status === 'paused';
    },
    fields() {
      return this.form?.definition?.fields || [
        { key: 'name', type: 'native', field: 'name', label: 'Nome', required: true },
        { key: 'email', type: 'native', field: 'email', label: 'E-mail', required: true },
        { key: 'phone_number', type: 'native', field: 'phone_number', label: 'Telefone', required: false },
      ];
    },
    submitLabel() {
      return this.form?.branding?.submit_label || 'Enviar';
    },
  },
  mounted() {
    this.loadForm();
  },
  methods: {
    initValues() {
      this.values = {};
      this.fields.forEach(f => {
        const key = f.field || f.key;
        this.values[key] = '';
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
        this.error = respError?.message || respError?.error || 'Formulário indisponível.';
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
      try {
        const { data } = await axios.post(
          `/public/api/v1/account_forms/${accountId}/${slug}/submit`,
          {
            ...this.values,
            website_token: this.honeypot,
            utm_source: params.get('utm_source'),
            utm_medium: params.get('utm_medium'),
            utm_campaign: params.get('utm_campaign'),
            utm_term: params.get('utm_term'),
            utm_content: params.get('utm_content'),
          }
        );
        this.successMessage = data.message || 'Enviado com sucesso!';
      } catch (err) {
        const respData = err?.response?.data;
        this.error = respData?.message || respData?.error || 'Não foi possível enviar. Tente novamente.';
      } finally {
        this.submitting = false;
      }
    },
    inputType(field) {
      if (field.field === 'email' || field.key === 'email') return 'email';
      if (field.field === 'phone_number' || field.key === 'phone_number') return 'tel';
      return 'text';
    },
    fieldKey(field) {
      return field.field || field.key;
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
        <p class="text-slate-600">{{ error || 'Formulário indisponível.' }}</p>
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
        <img
          v-if="form.branding && form.branding.logo_url"
          :src="form.branding.logo_url"
          alt=""
          class="object-contain h-10 mb-4 max-w-[160px]"
        />
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
          <label
            v-for="field in fields"
            :key="fieldKey(field)"
            class="block text-sm"
          >
            <span class="mb-1 block text-slate-700">
              {{ field.label }}<span v-if="field.required" class="ml-0.5 text-red-500" aria-hidden="true">*</span>
            </span>
            <input
              v-model="values[fieldKey(field)]"
              :type="inputType(field)"
              :required="field.required"
              :placeholder="inputType(field) === 'tel' ? '+5511999999999' : ''"
              :autocomplete="inputType(field) === 'email' ? 'email' : inputType(field) === 'tel' ? 'tel' : 'name'"
              class="w-full px-3 py-2 border rounded-lg border-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-0 transition-shadow"
              :style="{ '--tw-ring-color': primaryColor }"
            />
          </label>

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
