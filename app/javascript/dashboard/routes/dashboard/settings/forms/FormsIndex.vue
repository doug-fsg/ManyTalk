<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'dashboard/composables/route';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
import FormCard from './FormCard.vue';
import FormCreateModal from './FormCreateModal.vue';
import FormIconButton from './FormIconButton.vue';

const store = useStore();
const getters = useStoreGetters();
const router = useRouter();
const { t } = useI18n();

const showCreateModal = ref(false);
const loading = ref({});
const selectedForm = ref(null);
const deleteConfirmDialog = ref(null);

const records = computed(() => getters['accountForms/getAccountForms'].value);
const uiFlags = computed(() => getters['accountForms/getAccountFormUIFlags'].value);
const fetchError = computed(() => uiFlags.value.fetchError);

const deleteConfirmTitle = computed(() =>
  t('ACCOUNT_FORM.LIST.DELETE_CONFIRM', {
    name: selectedForm.value ? selectedForm.value.name : '',
  })
);

const loadForms = () => store.dispatch('accountForms/get');

onMounted(loadForms);

const goToWorkflows = () => {
  router.push({ name: 'workflows_list' });
};

const openCreate = () => {
  showCreateModal.value = true;
};

const openDetail = form => {
  router.push({ name: 'forms_show', params: { formId: form.id } });
};

const onCreated = form => {
  showCreateModal.value = false;
  useAlert(t('ACCOUNT_FORM.CREATE.SUCCESS'));
  openDetail(form);
};

const updateStatus = async (form, status) => {
  loading.value[form.id] = true;
  try {
    await store.dispatch('accountForms/updateStatus', { id: form.id, status });
    useAlert(t('ACCOUNT_FORM.DETAIL.STATUS_SUCCESS'));
  } catch {
    useAlert(t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
  } finally {
    loading.value[form.id] = false;
  }
};

const requestDelete = async form => {
  selectedForm.value = form;
  const ok = await (deleteConfirmDialog.value &&
    deleteConfirmDialog.value.showConfirmation());
  if (!ok) return;

  loading.value[form.id] = true;
  try {
    await store.dispatch('accountForms/delete', form.id);
  } catch {
    useAlert(t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
  } finally {
    loading.value[form.id] = false;
    selectedForm.value = null;
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('ACCOUNT_FORM.LOADING')"
    :no-records-found="!records.length && !fetchError"
    :no-records-message="$t('ACCOUNT_FORM.LIST.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('ACCOUNT_FORM.HEADER')"
        :description="$t('ACCOUNT_FORM.DESCRIPTION')"
        feature-name=""
      >
        <template #actions>
          <div class="flex items-center gap-2">
            <FormIconButton
              icon="chevron-left"
              :tooltip="$t('ACCOUNT_FORM.LIST.BACK_TO_WORKFLOWS_TOOLTIP')"
              @click="goToWorkflows"
            />
            <woot-button
              v-tooltip.top="$t('ACCOUNT_FORM.LIST.CREATE_TOOLTIP')"
              icon="add-circle"
              @click="openCreate"
            >
              {{ $t('ACCOUNT_FORM.LIST.CREATE') }}
            </woot-button>
          </div>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div
        v-if="fetchError"
        class="flex flex-col items-center gap-3 py-12 text-center"
      >
        <p class="text-sm text-slate-500 dark:text-slate-400">
          {{ $t('ACCOUNT_FORM.LIST.FETCH_ERROR') }}
        </p>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          @click="loadForms"
        >
          {{ $t('WORKFLOW.EDITOR.RETRY') }}
        </woot-button>
      </div>
      <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        <FormCard
          v-for="form in records"
          :key="form.id"
          :form="form"
          :loading="loading[form.id]"
          @open="openDetail(form)"
          @publish="updateStatus(form, 'published')"
          @pause="updateStatus(form, 'paused')"
          @delete="requestDelete(form)"
        />
      </div>
    </template>

    <ConfirmationModal
      ref="deleteConfirmDialog"
      :title="deleteConfirmTitle"
      :description="$t('ACCOUNT_FORM.LIST.DELETE_CONFIRM_DESCRIPTION')"
    />
    <FormCreateModal
      v-if="showCreateModal"
      @close="showCreateModal = false"
      @created="onCreated"
    />
  </SettingsLayout>
</template>
