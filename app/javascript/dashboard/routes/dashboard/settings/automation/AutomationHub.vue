<script setup>
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'dashboard/composables/route';
import { useStoreGetters } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const route = useRoute();
const router = useRouter();
const getters = useStoreGetters();

const accountId = computed(() => getters.getCurrentAccountId.value);

const isAdministrator = computed(
  () => getters.getCurrentRole.value === 'administrator'
);

const isWorkflowsEnabled = computed(() =>
  getters['accounts/isFeatureEnabledonAccount'].value(
    accountId.value,
    FEATURE_FLAGS.WORKFLOWS
  )
);

const activeTab = computed(() => {
  if (
    isWorkflowsEnabled.value &&
    (route.name === 'workflows_list' ||
      route.name === 'workflows_new' ||
      route.name === 'workflows_edit')
  ) {
    return 'workflows';
  }
  return 'automations';
});

const switchTab = tab => {
  if (tab === 'workflows' && !isWorkflowsEnabled.value) return;
  router.push({
    name: tab === 'workflows' ? 'workflows_list' : 'automation_list',
  });
};

watch(
  [() => route.name, isWorkflowsEnabled],
  () => {
    if (
      !isWorkflowsEnabled.value &&
      route.name === 'workflows_list'
    ) {
      router.replace({
        name: 'automation_list',
        params: { accountId: route.params.accountId },
      });
    }
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col flex-1 overflow-hidden bg-white dark:bg-slate-900">
    <!-- Tab bar -->
    <div
      class="flex items-center gap-1 px-4 pt-3 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900"
    >
      <button
        type="button"
        class="relative px-4 py-2.5 text-sm font-medium transition-colors duration-150 cursor-pointer rounded-t-lg -mb-px"
        :class="
          activeTab === 'automations'
            ? 'text-woot-600 dark:text-woot-400 border-b-2 border-woot-500'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 border-b-2 border-transparent'
        "
        @click="switchTab('automations')"
      >
        {{ $t('AUTOMATION.TABS.CLASSIC') }}
      </button>

      <button
        v-if="isWorkflowsEnabled"
        type="button"
        class="relative flex items-center gap-2 px-4 py-2.5 text-sm font-medium transition-colors duration-150 cursor-pointer rounded-t-lg -mb-px"
        :class="
          activeTab === 'workflows'
            ? 'text-woot-600 dark:text-woot-400 border-b-2 border-woot-500'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 border-b-2 border-transparent'
        "
        @click="switchTab('workflows')"
      >
        {{ $t('WORKFLOW.TABS.WORKFLOWS') }}
        <span
          class="text-xs font-semibold px-1.5 py-0.5 rounded-md bg-woot-500 text-white leading-none"
        >
          {{ $t('WORKFLOW.TABS.NEW_BADGE') }}
        </span>
      </button>
    </div>

    <div
      v-if="activeTab === 'automations' && !isAdministrator"
      class="flex items-center gap-2 px-4 py-2 text-xs bg-yellow-50 dark:bg-yellow-900/20 border-b border-yellow-200 dark:border-yellow-700/40 text-yellow-700 dark:text-yellow-300"
    >
      <svg
        class="w-3.5 h-3.5 shrink-0"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
        />
      </svg>
      {{ $t('WORKFLOW.BANNER.ADMIN_ONLY_AUTOMATIONS') }}
    </div>

    <router-view />
  </div>
</template>
