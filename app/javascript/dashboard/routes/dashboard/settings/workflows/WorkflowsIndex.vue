<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'dashboard/composables/route';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
import WorkflowCreateModal from './WorkflowCreateModal.vue';
import WorkflowCard from './WorkflowCard.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const store = useStore();
const getters = useStoreGetters();
const router = useRouter();
const { t } = useI18n();
const confirmDialog = ref(null);
const deleteConfirmDialog = ref(null);
const selectedWorkflow = ref(null);
const loading = ref({});
const showCreateModal = ref(false);

const records = computed(() => getters['workflows/getWorkflows'].value);
const uiFlags = computed(() => getters['workflows/getUIFlags'].value);
const fetchError = computed(() => getters['workflows/getWorkflowFetchError'].value);

const loadWorkflows = () => store.dispatch('workflows/get');

onMounted(loadWorkflows);

const openNew = () => {
  showCreateModal.value = true;
};

const openEdit = workflow =>
  router.push({ name: 'workflows_edit', params: { workflowId: workflow.id } });

const toggleWorkflow = async ({ id, active }) => {
  if (!active) {
    const ok = await confirmDialog.value?.showConfirmation();
    if (!ok) return;
  }

  try {
    await store.dispatch('workflows/toggleActive', id);
    useAlert(t('WORKFLOW.TOGGLE.SUCCESS'));
  } catch (error) {
    const detail = error?.message;
    useAlert(detail || t('WORKFLOW.TOGGLE.ERROR'));
  }
};

const cloneWorkflow = async workflow => {
  loading.value[workflow.id] = true;
  try {
    await store.dispatch('workflows/clone', workflow.id);
    useAlert(t('WORKFLOW.CLONE.SUCCESS'));
  } catch {
    useAlert(t('WORKFLOW.CLONE.ERROR'));
  } finally {
    loading.value[workflow.id] = false;
  }
};

const requestDeleteWorkflow = async workflow => {
  selectedWorkflow.value = workflow;
  const ok = await deleteConfirmDialog.value?.showConfirmation();
  if (!ok) return;

  loading.value[workflow.id] = true;
  try {
    await store.dispatch('workflows/delete', workflow.id);
    useAlert(t('WORKFLOW.DELETE.SUCCESS'));
  } catch {
    useAlert(t('WORKFLOW.DELETE.ERROR'));
  } finally {
    loading.value[workflow.id] = false;
    selectedWorkflow.value = null;
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('WORKFLOW.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('WORKFLOW.LIST.EMPTY')"
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
        v-if="fetchError"
        class="flex flex-col items-center gap-3 py-12 text-center"
      >
        <p class="text-sm text-slate-500 dark:text-slate-400">
          {{ $t('WORKFLOW.LIST.FETCH_ERROR') }}
        </p>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          @click="loadWorkflows"
        >
          {{ $t('WORKFLOW.EDITOR.RETRY') }}
        </woot-button>
      </div>
      <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        <WorkflowCard
          v-for="workflow in records"
          :key="workflow.id"
          :workflow="workflow"
          :loading="loading[workflow.id]"
          @toggle="toggleWorkflow"
          @edit="openEdit"
          @clone="cloneWorkflow"
          @delete="requestDeleteWorkflow"
        />
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
    <WorkflowCreateModal
      :show="showCreateModal"
      @close="showCreateModal = false"
    />
  </SettingsLayout>
</template>
