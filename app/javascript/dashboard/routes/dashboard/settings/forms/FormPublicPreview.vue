<script setup>
import { computed } from 'vue';

const props = defineProps({
  branding: { type: Object, required: true },
  settings: { type: Object, default: () => ({}) },
  definition: { type: Object, default: () => ({ fields: [] }) },
});

const primaryColor = computed(() => props.branding.primary_color || '#1f93ff');

const fields = computed(() =>
  props.definition?.fields || [
    { key: 'name', label: 'Nome', required: true },
    { key: 'email', label: 'E-mail', required: true },
    { key: 'phone_number', label: 'Telefone', required: false },
  ]
);
</script>

<template>
  <div
    class="p-6 border rounded-xl border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 pointer-events-none select-none"
  >
    <div v-if="branding.logo_url" class="mb-4">
      <img
        :src="branding.logo_url"
        alt=""
        class="object-contain h-10 max-w-[160px]"
      />
    </div>
    <h4 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
      {{ branding.header_title || 'Formulário' }}
    </h4>
    <p
      v-if="branding.header_description"
      class="mt-1 mb-4 text-sm text-slate-500 dark:text-slate-400"
    >
      {{ branding.header_description }}
    </p>
    <div v-else class="mb-4" />

    <div class="space-y-3">
      <div v-for="field in fields" :key="field.key">
        <span class="block mb-1 text-xs text-slate-600 dark:text-slate-400">
          {{ field.label }}<span v-if="field.required" class="ml-0.5 text-red-400">*</span>
        </span>
        <div class="h-8 rounded-lg bg-slate-100 dark:bg-slate-800" />
      </div>
    </div>

    <button
      type="button"
      class="w-full px-4 py-2 mt-4 text-sm font-medium text-white rounded-lg"
      :style="{ backgroundColor: primaryColor }"
      tabindex="-1"
    >
      {{ $t('ACCOUNT_FORM.APPEARANCE.SUBMIT') }}
    </button>
  </div>
</template>
