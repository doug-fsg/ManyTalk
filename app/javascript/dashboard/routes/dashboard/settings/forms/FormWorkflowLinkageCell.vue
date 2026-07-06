<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { LINKAGE_STATES } from './formWorkflowLinkage';

const props = defineProps({
  form: { type: Object, required: true },
  linkage: { type: Object, required: true },
});

const emit = defineEmits(['connect']);

const { t } = useI18n();

const state = computed(() => props.linkage?.state || LINKAGE_STATES.CONTACT_ONLY);
const workflows = computed(() => props.linkage?.workflows || []);
const primaryWorkflow = computed(() => workflows.value[0] || null);
const extraCount = computed(() => Math.max(workflows.value.length - 1, 0));

const showConnectCta = computed(
  () =>
    props.form.status === 'published' &&
    state.value === LINKAGE_STATES.CONTACT_ONLY
);

const badgeClass = computed(() => {
  switch (state.value) {
    case LINKAGE_STATES.AUTOMATES:
      return 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300';
    case LINKAGE_STATES.PAUSED_FLOW:
      return 'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300';
    default:
      return 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300';
  }
});

const icon = computed(() => {
  switch (state.value) {
    case LINKAGE_STATES.AUTOMATES:
      return 'flow';
    case LINKAGE_STATES.PAUSED_FLOW:
      return 'pause';
    default:
      return 'people';
  }
});

const badgeLabel = computed(() => {
  switch (state.value) {
    case LINKAGE_STATES.AUTOMATES:
      return t('ACCOUNT_FORM.LIST.FLOW.AUTOMATES');
    case LINKAGE_STATES.PAUSED_FLOW:
      return t('ACCOUNT_FORM.LIST.FLOW.PAUSED_FLOW');
    default:
      return t('ACCOUNT_FORM.LIST.FLOW.CONTACT_ONLY');
  }
});

const workflowNamesTooltip = computed(() =>
  workflows.value.map(workflow => workflow.name).join('\n')
);

const tooltipText = computed(() => {
  if (state.value === LINKAGE_STATES.AUTOMATES && primaryWorkflow.value) {
    return t('ACCOUNT_FORM.LIST.FLOW.TOOLTIP_AUTOMATES', {
      name: primaryWorkflow.value.name,
    });
  }
  if (state.value === LINKAGE_STATES.PAUSED_FLOW) {
    const hint = t('ACCOUNT_FORM.LIST.FLOW.TOOLTIP_PAUSED_HINT');
    return `${t('ACCOUNT_FORM.LIST.FLOW.TOOLTIP_PAUSED')}\n${hint}`;
  }
  return t('ACCOUNT_FORM.LIST.FLOW.TOOLTIP_CONTACT_ONLY');
});

const workflowEditRoute = workflow => ({
  name: 'workflows_edit',
  params: { workflowId: workflow.id },
});
</script>

<template>
  <div
    v-tooltip.top="tooltipText"
    class="flex flex-col gap-1 min-w-[180px]"
  >
    <div class="flex items-center gap-1.5 flex-wrap">
      <span
        class="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium rounded-full"
        :class="badgeClass"
      >
        <fluent-icon :icon="icon" size="12" aria-hidden="true" />
        <span>{{ badgeLabel }}</span>
      </span>

      <button
        v-if="showConnectCta"
        type="button"
        class="text-xs font-medium text-woot-500 hover:text-woot-600 dark:text-woot-400 dark:hover:text-woot-300 transition-colors duration-200 cursor-pointer"
        @click="emit('connect')"
      >
        {{ $t('ACCOUNT_FORM.LIST.FLOW.CONNECT') }}
      </button>

      <router-link
        v-else-if="state === LINKAGE_STATES.PAUSED_FLOW && primaryWorkflow"
        :to="workflowEditRoute(primaryWorkflow)"
        class="text-xs font-medium text-woot-500 hover:text-woot-600 dark:text-woot-400 dark:hover:text-woot-300 transition-colors duration-200 cursor-pointer"
      >
        {{ $t('ACCOUNT_FORM.LIST.FLOW.VIEW_FLOW') }}
      </router-link>
    </div>

    <div
      v-if="primaryWorkflow"
      class="flex items-center gap-1 text-xs text-slate-600 dark:text-slate-300 min-w-0"
    >
      <router-link
        :to="workflowEditRoute(primaryWorkflow)"
        v-tooltip.top="workflowNamesTooltip"
        class="truncate hover:text-woot-600 dark:hover:text-woot-400 transition-colors duration-200 cursor-pointer"
      >
        {{ primaryWorkflow.name }}
      </router-link>
      <span
        v-if="extraCount"
        v-tooltip.top="workflowNamesTooltip"
        class="shrink-0 text-slate-400 dark:text-slate-500"
      >
        {{ $t('ACCOUNT_FORM.LIST.FLOW.MORE_FLOWS', { count: extraCount }) }}
      </span>
    </div>
  </div>
</template>
