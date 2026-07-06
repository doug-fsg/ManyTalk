<script setup>
import { computed, ref } from 'vue';
import FormPublicPreview from './FormPublicPreview.vue';
import { resolveFormBranding } from 'shared/helpers/formBrandingHelpers';

const props = defineProps({
  branding: { type: Object, required: true },
  settings: { type: Object, default: () => ({}) },
  definition: { type: Object, default: () => ({ fields: [] }) },
  contactAttributes: { type: Array, default: () => [] },
});

const viewMode = ref('desktop');
const pageStyle = computed(
  () => resolveFormBranding(props.branding).pageStyle
);
</script>

<template>
  <aside
    class="flex flex-col h-full overflow-y-auto border-l border-slate-100 dark:border-slate-800 px-4 pt-4 pb-6"
    :style="pageStyle"
  >

    <div class="flex items-center justify-between mb-4 shrink-0">
      <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
        {{ $t('ACCOUNT_FORM.PREVIEW.TITLE') }}
      </p>

      <div class="flex items-center gap-0.5 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-0.5">
        <button
          type="button"
          class="flex items-center gap-1 px-2 py-1 rounded-md text-[11px] font-medium transition-all duration-150"
          :class="
            viewMode === 'desktop'
              ? 'bg-woot-500 text-white shadow-sm'
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
          "
          @click="viewMode = 'desktop'"
        >
          <fluent-icon icon="globe" size="11" aria-hidden="true" />
          {{ $t('ACCOUNT_FORM.PREVIEW.DESKTOP') }}
        </button>
        <button
          type="button"
          class="flex items-center gap-1 px-2 py-1 rounded-md text-[11px] font-medium transition-all duration-150"
          :class="
            viewMode === 'mobile'
              ? 'bg-woot-500 text-white shadow-sm'
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
          "
          @click="viewMode = 'mobile'"
        >
          <fluent-icon icon="call" size="11" aria-hidden="true" />
          {{ $t('ACCOUNT_FORM.PREVIEW.MOBILE') }}
        </button>
      </div>
    </div>

    <div class="flex-1 flex items-start justify-center overflow-y-auto">
      <div
        v-if="viewMode === 'desktop'"
        class="w-full shadow-sm border border-slate-200 dark:border-slate-700 rounded-xl overflow-hidden"
      >
        <FormPublicPreview
          :branding="branding"
          :settings="settings"
          :definition="definition"
          :contact-attributes="contactAttributes"
          :is-mobile="false"
        />
      </div>

      <div
        v-else
        class="flex flex-col items-center"
      >
        <div
          class="relative w-[220px] bg-slate-800 dark:bg-slate-950 rounded-[32px] p-2.5 shadow-xl"
        >
          <div
            class="absolute top-4 left-1/2 -translate-x-1/2 w-16 h-3 bg-slate-700 dark:bg-slate-800 rounded-full z-10"
          />

          <div
            class="w-full rounded-[24px] overflow-hidden overflow-y-auto"
            :style="{ maxHeight: '440px', minHeight: '320px', ...pageStyle }"
          >

            <FormPublicPreview
              :branding="branding"
              :settings="settings"
              :definition="definition"
              :contact-attributes="contactAttributes"
              :is-mobile="true"
            />
          </div>
        </div>

        <div
          class="mt-3 w-20 h-1 bg-slate-300 dark:bg-slate-600 rounded-full"
        />
      </div>
    </div>
  </aside>
</template>
