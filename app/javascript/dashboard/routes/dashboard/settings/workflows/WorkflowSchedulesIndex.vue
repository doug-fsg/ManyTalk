<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import WorkflowScheduleRow from './WorkflowScheduleRow.vue';
import WorkflowScheduleModal from './WorkflowScheduleModal.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const deleteConfirmDialog = ref(null);
const selectedSchedule = ref(null);
const showModal = ref(false);
const editingSchedule = ref(null);
const loading = ref({});

const records = computed(() => getters['workflowSchedules/getSchedules'].value);
const uiFlags = computed(() => getters['workflowSchedules/getUIFlags'].value);
const fetchError = computed(() => getters['workflowSchedules/getFetchError'].value);
const tableHeaders = computed(() => t('WORKFLOW.SCHEDULES.TABLE_HEADER'));

const load = () => {
  store.dispatch('workflowSchedules/get');
  store.dispatch('workflows/get');
  store.dispatch('attributes/get');
};

onMounted(load);

const openNew = () => {
  editingSchedule.value = null;
  showModal.value = true;
};

const openEdit = schedule => {
  editingSchedule.value = schedule;
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
  editingSchedule.value = null;
};

const saveSchedule = async payload => {
  try {
    if (payload.id) {
      await store.dispatch('workflowSchedules/update', payload);
      useAlert(t('WORKFLOW.SCHEDULES.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('workflowSchedules/create', payload);
      useAlert(t('WORKFLOW.SCHEDULES.CREATE_SUCCESS'));
    }
    closeModal();
  } catch (error) {
    const apiError = error?.response?.data?.error;
    const message = Array.isArray(apiError) ? apiError.join(', ') : apiError;
    useAlert(message || t('WORKFLOW.SCHEDULES.SAVE_ERROR'));
  }
};

const toggleSchedule = async ({ id }) => {
  try {
    await store.dispatch('workflowSchedules/toggleActive', id);
    useAlert(t('WORKFLOW.SCHEDULES.TOGGLE_SUCCESS'));
  } catch (error) {
    useAlert(error?.message || t('WORKFLOW.SCHEDULES.TOGGLE_ERROR'));
  }
};

const requestDelete = async schedule => {
  selectedSchedule.value = schedule;
  const ok = await deleteConfirmDialog.value?.showConfirmation();
  if (!ok) return;
  loading.value[schedule.id] = true;
  try {
    await store.dispatch('workflowSchedules/delete', schedule.id);
    useAlert(t('WORKFLOW.SCHEDULES.DELETE_SUCCESS'));
  } catch {
    useAlert(t('WORKFLOW.SCHEDULES.DELETE_ERROR'));
  } finally {
    loading.value[schedule.id] = false;
    selectedSchedule.value = null;
  }
};
</script>

<template>
  <SettingsLayout
    compact
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('WORKFLOW.SCHEDULES.LOADING')"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        compact
        :title="$t('WORKFLOW.SCHEDULES.HEADER')"
        :description="$t('WORKFLOW.SCHEDULES.DESCRIPTION')"
        feature-name=""
      >
        <template #actions>
          <woot-button
            class="button nice rounded-lg"
            icon="add-circle"
            @click="openNew"
          >
            {{ $t('WORKFLOW.SCHEDULES.CREATE') }}
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
          {{ $t('WORKFLOW.SCHEDULES.FETCH_ERROR') }}
        </p>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          @click="load"
        >
          {{ $t('WORKFLOW.EDITOR.RETRY') }}
        </woot-button>
      </div>
      <EmptyState
        v-else-if="!records.length"
        :title="$t('WORKFLOW.SCHEDULES.EMPTY_TITLE')"
        :message="$t('WORKFLOW.SCHEDULES.EMPTY')"
      >
        <woot-button
          class="button nice rounded-lg"
          icon="add-circle"
          @click="openNew"
        >
          {{ $t('WORKFLOW.SCHEDULES.CREATE') }}
        </woot-button>
      </EmptyState>
      <table
        v-else
        class="min-w-full divide-y divide-slate-75 dark:divide-slate-700"
      >
        <thead>
          <th
            v-for="(header, index) in tableHeaders"
            :key="`${header}-${index}`"
            class="py-4 ltr:pr-4 rtl:pl-4 font-semibold text-slate-700 dark:text-slate-300"
            :class="index === tableHeaders.length - 1 ? 'text-right' : 'text-left'"
          >
            {{ header }}
          </th>
        </thead>
        <tbody
          class="divide-y divide-slate-50 dark:divide-slate-800 text-slate-700 dark:text-slate-300"
        >
          <WorkflowScheduleRow
            v-for="schedule in records"
            :key="schedule.id"
            :schedule="schedule"
            :loading="!!loading[schedule.id]"
            @toggle="toggleSchedule"
            @edit="openEdit"
            @delete="requestDelete"
          />
        </tbody>
      </table>
    </template>

    <ConfirmationModal
      ref="deleteConfirmDialog"
      :title="$t('WORKFLOW.SCHEDULES.DELETE_TITLE')"
      :description="$t('WORKFLOW.SCHEDULES.DELETE_DESCRIPTION')"
    />
    <WorkflowScheduleModal
      :show="showModal"
      :schedule="editingSchedule"
      @close="closeModal"
      @save="saveSchedule"
    />
  </SettingsLayout>
</template>
