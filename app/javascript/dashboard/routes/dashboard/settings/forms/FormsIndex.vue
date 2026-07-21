<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'dashboard/composables/route';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
import FormCreateModal from './FormCreateModal.vue';
import FormListToolbar from './FormListToolbar.vue';
import FormListRow from './FormListRow.vue';
import WorkflowCreateModal from '../workflows/WorkflowCreateModal.vue';
import { useFormListFilters } from './useFormListFilters';
import { buildContactsByFormRoute } from '../../contacts/utils/contactsNavigationHelper';

const store = useStore();
const getters = useStoreGetters();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const showCreateModal = ref(false);
const showConnectModal = ref(false);
const connectFormContext = ref(null);
const loading = ref({});
const selectedForm = ref(null);
const deleteConfirmDialog = ref(null);

const records = computed(() => getters['accountForms/getAccountForms'].value);
const uiFlags = computed(() => getters['accountForms/getAccountFormUIFlags'].value);
const fetchError = computed(() => uiFlags.value.fetchError);

const {
  searchQuery,
  statusFilter,
  flowFilter,
  filteredForms,
  linkageByFormId,
  hasActiveFilters,
} = useFormListFilters(records);

const deleteConfirmTitle = computed(() =>
  t('ACCOUNT_FORM.LIST.DELETE_CONFIRM', {
    name: selectedForm.value ? selectedForm.value.name : '',
  })
);

const connectFormId = computed(() =>
  connectFormContext.value ? connectFormContext.value.id : null
);

const connectFormName = computed(() =>
  connectFormContext.value ? connectFormContext.value.name : ''
);

const loadData = () => store.dispatch('accountForms/get');

onMounted(loadData);

watch(
  () => route.name,
  name => {
    if (name === 'forms_list') loadData();
  }
);

const openCreate = () => {
  showCreateModal.value = true;
};

const openConnectModal = form => {
  connectFormContext.value = { id: form.id, name: form.name };
  showConnectModal.value = true;
};

const closeConnectModal = () => {
  showConnectModal.value = false;
  connectFormContext.value = null;
};

const openDetail = form => {
  router.push({ name: 'forms_show', params: { formId: form.id } });
};

const openSubmissions = form => {
  router.push(buildContactsByFormRoute(route.params.accountId, form.id));
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
  } catch (error) {
    const message = error?.response?.data?.message;
    useAlert(message || t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
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
          <woot-button
            v-tooltip.top="$t('ACCOUNT_FORM.LIST.CREATE_TOOLTIP')"
            icon="add-circle"
            @click="openCreate"
          >
            {{ $t('ACCOUNT_FORM.LIST.CREATE') }}
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
          {{ $t('ACCOUNT_FORM.LIST.FETCH_ERROR') }}
        </p>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          @click="loadData"
        >
          {{ $t('WORKFLOW.EDITOR.RETRY') }}
        </woot-button>
      </div>

      <template v-else>
        <FormListToolbar
          :search-query.sync="searchQuery"
          :status-filter.sync="statusFilter"
          :flow-filter.sync="flowFilter"
        />

        <table class="min-w-full divide-y divide-slate-75 dark:divide-slate-700">
          <thead>
            <th
              v-for="thHeader in $t('ACCOUNT_FORM.LIST.TABLE_HEADER')"
              :key="thHeader"
              class="py-4 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300"
            >
              {{ thHeader }}
            </th>
          </thead>
          <tbody
            class="divide-y divide-slate-50 dark:divide-slate-800 text-slate-700 dark:text-slate-300"
          >
            <FormListRow
              v-for="form in filteredForms"
              :key="form.id"
              :form="form"
              :linkage="linkageByFormId[form.id]"
              :loading="loading[form.id]"
              @open="openDetail(form)"
              @submissions="openSubmissions(form)"
              @publish="updateStatus(form, 'published')"
              @pause="updateStatus(form, 'paused')"
              @delete="requestDelete(form)"
              @connect="openConnectModal(form)"
            />
            <tr v-if="!filteredForms.length && hasActiveFilters">
              <td
                colspan="7"
                class="py-8 text-center text-sm text-slate-500 dark:text-slate-400"
              >
                {{ $t('ACCOUNT_FORM.LIST.FILTERS.NO_RESULTS') }}
              </td>
            </tr>
          </tbody>
        </table>
      </template>
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
    <WorkflowCreateModal
      :show="showConnectModal"
      :connect-form-id="connectFormId"
      :connect-form-name="connectFormName"
      @close="closeConnectModal"
    />
  </SettingsLayout>
</template>
