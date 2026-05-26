<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'dashboard/composables/route';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const store = useStore();
const getters = useStoreGetters();
const router = useRouter();
const { t, te } = useI18n();
const confirmDialog = ref(null);
const deleteConfirmDialog = ref(null);
const deletingId = ref(null);

const records = computed(() => getters['workflows/getWorkflows'].value);
const uiFlags = computed(() => getters['workflows/getUIFlags'].value);

onMounted(() => {
  store.dispatch('workflows/get');
});

const openNew = () => router.push({ name: 'workflows_new' });
const openEdit = workflow =>
  router.push({ name: 'workflows_edit', params: { workflowId: workflow.id } });

const toggleWorkflow = async workflow => {
  if (!workflow.active) {
    const ok = await confirmDialog.value?.showConfirmation();
    if (!ok) return;
  }
  try {
    await store.dispatch('workflows/toggleActive', workflow.id);
    useAlert(t('WORKFLOW.TOGGLE.SUCCESS'));
  } catch {
    useAlert(t('WORKFLOW.TOGGLE.ERROR'));
  }
};

const cloneWorkflow = async workflow => {
  try {
    await store.dispatch('workflows/clone', workflow.id);
    useAlert(t('WORKFLOW.CLONE.SUCCESS'));
  } catch {
    useAlert(t('WORKFLOW.CLONE.ERROR'));
  }
};

const requestDeleteWorkflow = async workflow => {
  const ok = await deleteConfirmDialog.value?.showConfirmation();
  if (!ok) return;
  deletingId.value = workflow.id;
  try {
    await store.dispatch('workflows/delete', workflow.id);
    useAlert(t('WORKFLOW.DELETE.SUCCESS'));
  } catch {
    useAlert(t('WORKFLOW.DELETE.ERROR'));
  } finally {
    deletingId.value = null;
  }
};

const triggerLabel = workflow => {
  const trigger = (workflow.graph?.nodes || []).find(n => n.type === 'trigger');
  const event = trigger?.data?.event_name || '';
  const path = `WORKFLOW.LIST.TRIGGER_LABELS.${event}`;
  if (event && te(path)) return t(path);
  return event || t('WORKFLOW.LIST.TRIGGER_UNKNOWN');
};

const stepCount = workflow => {
  return (workflow.graph?.nodes || []).filter(n => n.type !== 'trigger').length;
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('WORKFLOW.LOADING')"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('WORKFLOW.HEADER')"
        :description="$t('WORKFLOW.DESCRIPTION')"
        :link-text="$t('WORKFLOW.LEARN_MORE')"
        feature-name=""
      >
        <template #actions>
          <woot-button
            class="button nice rounded-md"
            icon="add-circle"
            @click="openNew"
          >
            {{ $t('WORKFLOW.LIST.CREATE') }}
          </woot-button>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div
        v-if="!records.length"
        class="flex flex-col items-center justify-center gap-4 py-16 px-4 text-center"
      >
        <div
          class="w-16 h-16 rounded-2xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center"
          aria-hidden="true"
        >
          <svg
            class="w-8 h-8 text-slate-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1.5"
              d="M13 10V3L4 14h7v7l9-11h-7z"
            />
          </svg>
        </div>
        <div>
          <p class="font-medium text-slate-700 dark:text-slate-200">
            {{ $t('WORKFLOW.LIST.EMPTY_TITLE') }}
          </p>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-1 max-w-md">
            {{ $t('WORKFLOW.LIST.EMPTY') }}
          </p>
        </div>
        <woot-button
          class="button nice rounded-md"
          icon="add-circle"
          @click="openNew"
        >
          {{ $t('WORKFLOW.LIST.CREATE') }}
        </woot-button>
      </div>

      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <div
          v-for="workflow in records"
          :key="workflow.id"
          class="group relative flex flex-col bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 hover:border-woot-400 dark:hover:border-woot-500 hover:shadow-md transition-[box-shadow,border-color] duration-150 overflow-hidden"
        >
          <div
            class="h-1 w-full shrink-0"
            :class="
              workflow.active
                ? 'bg-green-400'
                : 'bg-slate-200 dark:bg-slate-700'
            "
            aria-hidden="true"
          />

          <router-link
            :to="{
              name: 'workflows_edit',
              params: { workflowId: workflow.id },
            }"
            class="flex flex-col flex-1 gap-3 p-4 min-w-0 text-inherit no-underline outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-woot-500 dark:focus-visible:ring-woot-400 cursor-pointer touch-manipulation"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="flex-1 min-w-0 text-left">
                <p
                  class="font-semibold text-slate-900 dark:text-slate-50 truncate"
                >
                  {{ workflow.name }}
                </p>
                <p
                  v-if="workflow.description"
                  class="text-xs text-slate-500 dark:text-slate-400 truncate mt-0.5"
                >
                  {{ workflow.description }}
                </p>
              </div>
              <span
                class="shrink-0 text-xs font-medium px-2 py-0.5 rounded-full"
                :class="
                  workflow.active
                    ? 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300'
                    : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'
                "
              >
                {{
                  workflow.active
                    ? $t('WORKFLOW.LIST.ACTIVE')
                    : $t('WORKFLOW.LIST.INACTIVE')
                }}
              </span>
            </div>

            <div
              class="flex items-center gap-4 text-xs text-slate-500 dark:text-slate-400"
            >
              <span class="flex items-center gap-1 min-w-0">
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
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
                <span class="truncate">{{ triggerLabel(workflow) }}</span>
              </span>
              <span class="flex items-center gap-1 shrink-0 tabular-nums">
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
                    d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                  />
                </svg>
                {{ stepCount(workflow) }} {{ $t('WORKFLOW.LIST.STEPS') }}
              </span>
            </div>
          </router-link>

          <div
            class="flex items-center justify-between px-4 py-2 border-t border-slate-100 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50"
            @click.stop
          >
            <button
              type="button"
              class="text-xs font-medium transition-colors cursor-pointer px-2 py-1 rounded outline-none focus-visible:ring-2 focus-visible:ring-woot-500 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-50 dark:focus-visible:ring-offset-slate-900 touch-manipulation"
              :class="
                workflow.active
                  ? 'text-orange-600 hover:text-orange-700 hover:bg-orange-50 dark:hover:bg-orange-900/20'
                  : 'text-green-600 hover:text-green-700 hover:bg-green-50 dark:hover:bg-green-900/20'
              "
              @click="toggleWorkflow(workflow)"
            >
              {{
                workflow.active
                  ? $t('WORKFLOW.LIST.DEACTIVATE')
                  : $t('WORKFLOW.LIST.ACTIVATE')
              }}
            </button>

            <div class="flex items-center gap-1">
              <button
                type="button"
                :aria-label="$t('WORKFLOW.LIST.CLONE')"
                class="p-1.5 rounded text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-woot-500 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-50 dark:focus-visible:ring-offset-slate-900 touch-manipulation"
                @click="cloneWorkflow(workflow)"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                  />
                </svg>
              </button>
              <button
                type="button"
                :aria-label="$t('WORKFLOW.LIST.EDIT')"
                class="p-1.5 rounded text-slate-400 hover:text-woot-500 hover:bg-woot-50 dark:hover:bg-woot-900/20 transition-colors cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-woot-500 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-50 dark:focus-visible:ring-offset-slate-900 touch-manipulation"
                @click="openEdit(workflow)"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                  />
                </svg>
              </button>
              <button
                type="button"
                :aria-label="$t('WORKFLOW.LIST.DELETE')"
                :disabled="deletingId === workflow.id"
                class="p-1.5 rounded text-slate-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-red-500 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-50 dark:focus-visible:ring-offset-slate-900 disabled:opacity-50 disabled:cursor-not-allowed touch-manipulation"
                @click="requestDeleteWorkflow(workflow)"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                  />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </template>

    <ConfirmationModal
      ref="confirmDialog"
      :title="$t('WORKFLOW.ACTIVATE_MODAL.TITLE')"
      :description="$t('WORKFLOW.ACTIVATE_MODAL.DESCRIPTION')"
    />
    <ConfirmationModal
      ref="deleteConfirmDialog"
      :title="$t('WORKFLOW.DELETE_MODAL.TITLE')"
      :description="$t('WORKFLOW.DELETE_MODAL.DESCRIPTION')"
    />
  </SettingsLayout>
</template>
