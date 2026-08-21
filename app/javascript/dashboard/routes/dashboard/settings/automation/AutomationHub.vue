<script setup>
import {
  computed,
  watch,
  onMounted,
  onBeforeUnmount,
  nextTick,
  ref,
} from 'vue';
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

const showFormsTab = computed(() => isWorkflowsEnabled.value);

const activeTab = computed(() => {
  if (route.name === 'forms_list' || route.name === 'forms_show') {
    return 'forms';
  }
  if (route.name === 'workflows_list') {
    return 'workflows';
  }
  return 'automations';
});

const viewToggleContainer = ref(null);
const workflowsButton = ref(null);
const formsButton = ref(null);
const badgeStyle = ref({ left: '2px', width: '0px', opacity: 1 });

const switchTab = tab => {
  if (tab === 'workflows' && !isWorkflowsEnabled.value) return;
  if (tab === 'forms' && !showFormsTab.value) return;

  const routeNames = {
    workflows: 'workflows_list',
    forms: 'forms_list',
    automations: 'automation_list',
  };

  router
    .push({ name: routeNames[tab], params: { accountId: accountId.value } })
    .catch(err => {
      if (err && err.name !== 'NavigationDuplicated') throw err;
    });
};

const updateBadgePosition = () => {
  nextTick(() => {
    if (!viewToggleContainer.value || activeTab.value === 'automations') {
      badgeStyle.value = { ...badgeStyle.value, opacity: 0 };
      return;
    }

    const activeButton =
      activeTab.value === 'forms' ? formsButton.value : workflowsButton.value;

    if (!activeButton) return;

    const containerRect = viewToggleContainer.value.getBoundingClientRect();
    const buttonRect = activeButton.getBoundingClientRect();

    badgeStyle.value = {
      left: `${buttonRect.left - containerRect.left}px`,
      width: `${buttonRect.width}px`,
      opacity: 1,
    };
  });
};

watch(activeTab, updateBadgePosition);
watch(showFormsTab, updateBadgePosition);

watch(
  [() => route.name, isWorkflowsEnabled],
  () => {
    if (!isWorkflowsEnabled.value && route.name === 'workflows_list') {
      router.replace({
        name: 'automation_list',
        params: { accountId: route.params.accountId },
      });
    }
  },
  { immediate: true }
);

onMounted(() => {
  nextTick(() => {
    setTimeout(updateBadgePosition, 150);
  });
  window.addEventListener('resize', updateBadgePosition);
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', updateBadgePosition);
});
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full min-w-0 overflow-hidden bg-white dark:bg-slate-900"
  >
    <div
      v-if="isWorkflowsEnabled"
      class="flex items-center justify-between gap-4 px-4 py-3 bg-white border-b border-slate-200 dark:bg-slate-900 dark:border-slate-700"
    >
      <!-- Primary tabs: Fluxo de Atendimento + Formulários -->
      <div
        ref="viewToggleContainer"
        class="inline-flex items-center gap-0.5 bg-slate-100/60 rounded-lg p-0.5 dark:bg-slate-700/50 relative"
      >
        <div
          :style="badgeStyle"
          class="absolute h-[calc(100%-4px)] rounded-md bg-woot-500 dark:bg-woot-800 transition-all duration-300 ease-out top-[2px] z-0"
          style="pointer-events: none"
        />

        <button
          ref="workflowsButton"
          type="button"
          :class="[
            'px-2.5 py-1.5 rounded-lg transition-colors duration-200 ease-smooth flex items-center gap-1.5 text-xs font-medium relative z-10',
            activeTab === 'workflows'
              ? 'text-white'
              : 'text-slate-600 dark:text-slate-300',
          ]"
          @click="switchTab('workflows')"
        >
          <fluent-icon icon="flash-settings" size="14" />
          <span>{{ $t('WORKFLOW.TABS.WORKFLOWS') }}</span>
          <span
            class="inline-block px-1 font-medium leading-4 rounded-lg text-xxs border"
            :class="
              activeTab === 'workflows'
                ? 'text-green-200 border-green-300'
                : 'text-green-500 border-green-400'
            "
          >
            {{ $t('SIDEBAR.BETA') }}
          </span>
        </button>

        <button
          v-if="showFormsTab"
          ref="formsButton"
          type="button"
          :class="[
            'px-2.5 py-1.5 rounded-lg transition-colors duration-200 ease-smooth flex items-center gap-1.5 text-xs font-medium relative z-10',
            activeTab === 'forms'
              ? 'text-white'
              : 'text-slate-600 dark:text-slate-300',
          ]"
          @click="switchTab('forms')"
        >
          <fluent-icon icon="clipboard" size="14" />
          <span>{{ $t('WORKFLOW.TABS.FORMS') }}</span>
        </button>
      </div>

      <!-- Classic mode — secondary, top-right -->
      <button
        type="button"
        class="shrink-0 text-xs transition-colors duration-150 cursor-pointer focus-visible:outline-none focus-visible:underline"
        :class="
          activeTab === 'automations'
            ? 'text-slate-500 dark:text-slate-400 font-medium'
            : 'text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300'
        "
        :aria-current="activeTab === 'automations' ? 'page' : undefined"
        @click="switchTab('automations')"
      >
        {{ $t('AUTOMATION.TABS.CLASSIC') }}
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
        aria-hidden="true"
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

    <div class="flex-1 min-h-0 overflow-auto">
      <router-view />
    </div>
  </div>
</template>
