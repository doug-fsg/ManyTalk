<script setup>
import { computed } from 'vue';
import { openAiUpsellWhatsApp } from 'dashboard/helper/workflowsAiFeatureGuard';
import { getWorkflowNodeVisual } from './workflowLogicFlowNodes';

defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['close']);

const benefitKeys = ['BENEFIT_1', 'BENEFIT_2', 'BENEFIT_3'];
const aiIconPath = computed(() => getWorkflowNodeVisual('ai_outreach').icon);

const close = () => emit('close');

const requestModule = () => {
  openAiUpsellWhatsApp();
  close();
};
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="close"
    :show-close-button="false"
    :close-on-backdrop-click="false"
  >
    <div class="workflow-ai-upsell flex w-full flex-col">
      <header class="bg-violet-600 px-8 pb-5 pt-8 text-white">
        <div class="mb-2 flex items-center gap-2">
          <span
            class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-white bg-opacity-10"
            aria-hidden="true"
          >
            <svg
              class="h-4 w-4 text-white"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1.75"
                :d="aiIconPath"
              />
            </svg>
          </span>
          <p
            class="text-[11px] font-semibold uppercase tracking-widest text-white"
          >
            ManyTalks IA
          </p>
        </div>

        <h2 class="text-base font-semibold leading-6 text-white">
          {{ $t('WORKFLOW.EDITOR.AI_UPSELL.TITLE') }}
        </h2>
        <p class="mt-2 text-sm leading-5 text-violet-100">
          {{ $t('WORKFLOW.EDITOR.AI_UPSELL.SUBTITLE') }}
        </p>
      </header>

      <div class="space-y-4 px-8 pb-8 pt-6">
        <div class="grid grid-cols-3 gap-2">
          <div
            v-for="key in benefitKeys"
            :key="key"
            class="rounded-lg border border-solid border-slate-100 bg-slate-25 p-3 transition-all duration-200 ease-out hover:-translate-y-0.5 hover:border-violet-200 hover:bg-violet-50 hover:shadow-md dark:border-slate-700 dark:bg-slate-800 dark:hover:border-violet-600 dark:hover:bg-violet-900/30"
          >
            <p
              class="text-sm font-medium leading-tight text-slate-800 dark:text-slate-100"
            >
              {{ $t(`WORKFLOW.EDITOR.AI_UPSELL.${key}`) }}
            </p>
            <p class="mt-1 text-xs leading-snug text-slate-500 dark:text-slate-400">
              {{ $t(`WORKFLOW.EDITOR.AI_UPSELL.${key}_DESC`) }}
            </p>
          </div>
        </div>

        <p class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('WORKFLOW.EDITOR.AI_UPSELL.FOOTER') }}
        </p>

        <div class="flex flex-col gap-2 pt-2">
          <button
            type="button"
            class="inline-flex h-10 w-full items-center justify-center gap-2 rounded-lg bg-violet-600 px-2.5 text-sm font-medium text-white transition-all duration-200 ease-out hover:-translate-y-0.5 hover:bg-violet-700 hover:shadow-md dark:bg-violet-600 dark:text-white dark:hover:bg-violet-700"
            @click="requestModule"
          >
            {{ $t('WORKFLOW.EDITOR.AI_UPSELL.CTA') }}
          </button>

          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="expanded"
            is-expanded
            class="transition-transform duration-200 ease-out hover:-translate-y-0.5"
            @click="close"
          >
            {{ $t('WORKFLOW.EDITOR.AI_UPSELL.CLOSE') }}
          </woot-button>
        </div>
      </div>
    </div>
  </woot-modal>
</template>

<style lang="scss">
.modal-mask .modal-container:has(.workflow-ai-upsell) {
  @apply w-full max-w-md overflow-hidden p-0;
}
</style>
