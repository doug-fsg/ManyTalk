<script setup>
import { computed, onMounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import CustomRoleForm from './CustomRoleForm.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const showForm = ref(false);
const showDeletePopup = ref(false);
const selectedRole = ref(null);

const records = computed(() => getters['customRoles/getCustomRoles'].value);
const uiFlags = computed(() => getters['customRoles/getUIFlags'].value);

onMounted(() => {
  store.dispatch('customRoles/get');
});

const openCreate = () => {
  selectedRole.value = null;
  showForm.value = true;
};

const openEdit = role => {
  selectedRole.value = role;
  showForm.value = true;
};

const hideForm = () => {
  showForm.value = false;
  selectedRole.value = null;
};

const openDelete = role => {
  selectedRole.value = role;
  showDeletePopup.value = true;
};

const confirmDelete = async () => {
  try {
    await store.dispatch('customRoles/delete', selectedRole.value.id);
    useAlert(t('CUSTOM_ROLE.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('CUSTOM_ROLE.DELETE.API.ERROR_MESSAGE'));
  } finally {
    showDeletePopup.value = false;
    selectedRole.value = null;
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('CUSTOM_ROLE.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('CUSTOM_ROLE.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('CUSTOM_ROLE.HEADER')"
        :description="$t('CUSTOM_ROLE.DESCRIPTION')"
        :back-button-label="$t('AGENT_MGMT.HEADER')"
        :back-button-url="{ name: 'agent_list' }"
      >
        <template #actions>
          <woot-button
            class="button nice rounded-lg"
            icon="add-circle"
            @click="openCreate"
          >
            {{ $t('CUSTOM_ROLE.HEADER_BTN_TXT') }}
          </woot-button>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <table class="min-w-full divide-y divide-slate-75 dark:divide-slate-700">
        <thead>
          <th
            class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('CUSTOM_ROLE.LIST.NAME') }}
          </th>
          <th
            class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('CUSTOM_ROLE.LIST.PERMISSIONS') }}
          </th>
          <th />
        </thead>
        <tbody
          class="divide-y divide-slate-25 dark:divide-slate-800 text-slate-700 dark:text-slate-100"
        >
          <tr v-for="role in records" :key="role.id">
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <span class="block font-medium">{{ role.name }}</span>
              <span class="text-sm text-slate-500">{{
                role.description
              }}</span>
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4 text-sm">
              {{ role.permissions.length }}
            </td>
            <td class="py-4">
              <div class="flex justify-end gap-1">
                <woot-button
                  variant="smooth"
                  size="tiny"
                  color-scheme="secondary"
                  icon="edit"
                  @click="openEdit(role)"
                />
                <woot-button
                  variant="smooth"
                  size="tiny"
                  color-scheme="alert"
                  icon="dismiss-circle"
                  @click="openDelete(role)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <woot-modal :show="showForm" :on-close="hideForm">
      <CustomRoleForm
        v-if="showForm"
        :selected-role="selectedRole"
        @close="hideForm"
      />
    </woot-modal>

    <woot-delete-modal
      :show.sync="showDeletePopup"
      :on-close="() => (showDeletePopup = false)"
      :on-confirm="confirmDelete"
      :title="$t('CUSTOM_ROLE.DELETE.CONFIRM.TITLE')"
      :message="$t('CUSTOM_ROLE.DELETE.CONFIRM.MESSAGE')"
      :message-value="selectedRole ? ` ${selectedRole.name}` : ''"
      :confirm-text="$t('CUSTOM_ROLE.DELETE.CONFIRM.YES')"
      :reject-text="$t('CUSTOM_ROLE.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
