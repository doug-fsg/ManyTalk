<script setup>
import { computed, onMounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import AiAttendantAPI from 'dashboard/api/aiAttendant';
import AiAttendantUsageCard from './AiAttendantUsageCard.vue';
import AiAttendantTestModal from './AiAttendantTestModal.vue';
import { avatarPreviewUrl } from './aiAttendantAvatars';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const records = ref([]);
const usage = ref(null);
const isFetching = ref(true);
const showDeleteConfirmationPopup = ref(false);
const showTestPopup = ref(false);
const showUsage = ref(false);
const selectedConfig = ref({});
const togglingId = ref(null);

const inboxes = computed(() => getters['inboxes/getInboxes']?.value || []);

const inboxLabels = config => {
  const ids = Array.isArray(config.inbox_ids)
    ? config.inbox_ids
    : config.inbox_id
      ? [config.inbox_id]
      : [];
  if (!ids.length) return '—';
  return ids
    .map(id => {
      const inbox = inboxes.value.find(
        item => Number(item.id) === Number(id)
      );
      return (
        inbox?.name || t('AI_ATTENDANT.LIST.UNKNOWN_INBOX', { id })
      );
    })
    .join(', ');
};

const scheduleLabel = mode => t(`AI_ATTENDANT.SCHEDULE.${mode || 'always'}`);

const statusLabel = config => {
  if (config.pause_reason === 'no_credits') {
    return t('AI_ATTENDANT.LIST.PAUSED_CREDITS');
  }
  if (config.pause_reason === 'admin') {
    return t('AI_ATTENDANT.LIST.PAUSED_ADMIN');
  }
  return config.active
    ? t('AI_ATTENDANT.LIST.ACTIVE')
    : t('AI_ATTENDANT.LIST.INACTIVE');
};

const statusBadgeClass = config => {
  if (config.pause_reason === 'no_credits') {
    return 'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200';
  }
  if (config.pause_reason === 'admin') {
    return 'bg-yellow-100 text-yellow-900 dark:bg-yellow-900/40 dark:text-yellow-200';
  }
  if (config.active) {
    return 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200';
  }
  return 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300';
};

const agentDisplayName = config =>
  config.digital_agent_name || t('AI_ATTENDANT.LIST.UNNAMED_AGENT');

const fetchRecords = async () => {
  isFetching.value = true;
  try {
    const [configsResponse, usageResponse] = await Promise.all([
      AiAttendantAPI.get(),
      AiAttendantAPI.getUsage(),
    ]);
    records.value = configsResponse.data || [];
    usage.value = usageResponse.data || null;
  } catch (error) {
    useAlert(t('AI_ATTENDANT.ERROR'));
  } finally {
    isFetching.value = false;
  }
};

const toggleActive = async (config, nextActive) => {
  if (nextActive && !config.digital_agent_name) {
    useAlert(t('AI_ATTENDANT.TOGGLE.ERROR_ACTIVE'));
    return;
  }
  togglingId.value = config.id;
  try {
    await AiAttendantAPI.update(config.id, {
      active: nextActive,
      pause_reason: nextActive ? null : 'admin',
    });
    await fetchRecords();
  } catch (error) {
    useAlert(t('AI_ATTENDANT.EDIT.API.ERROR_MESSAGE'));
  } finally {
    togglingId.value = null;
  }
};

const openDeletePopup = config => {
  selectedConfig.value = config;
  showDeleteConfirmationPopup.value = true;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const confirmDeletion = async () => {
  const id = selectedConfig.value.id;
  closeDeletePopup();
  try {
    await AiAttendantAPI.delete(id);
    useAlert(t('AI_ATTENDANT.DELETE.API.SUCCESS_MESSAGE'));
    await fetchRecords();
  } catch (error) {
    useAlert(t('AI_ATTENDANT.DELETE.API.ERROR_MESSAGE'));
  }
};

const openTestPopup = config => {
  selectedConfig.value = config;
  showTestPopup.value = true;
};

const closeTestPopup = () => {
  showTestPopup.value = false;
};

onMounted(() => {
  store.dispatch('inboxes/get');
  fetchRecords();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isFetching"
    :loading-message="$t('AI_ATTENDANT.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('AI_ATTENDANT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('AI_ATTENDANT.HEADER')"
        :description="$t('AI_ATTENDANT.DESCRIPTION')"
      >
        <template #actions>
          <woot-button
            v-if="usage"
            variant="smooth"
            color-scheme="secondary"
            icon="chart"
            @click="showUsage = !showUsage"
          >
            {{
              showUsage
                ? $t('AI_ATTENDANT.USAGE.TOGGLE_HIDE')
                : $t('AI_ATTENDANT.USAGE.TOGGLE')
            }}
          </woot-button>
          <router-link
            :to="{ name: 'settings_ia_new' }"
            class="button rounded-lg primary"
          >
            <fluent-icon icon="add-circle" />
            <span class="button__content">
              {{ $t('AI_ATTENDANT.HEADER_BTN_TXT') }}
            </span>
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #preBody>
      <transition name="slide-up">
        <AiAttendantUsageCard v-if="usage && showUsage" :usage="usage" />
      </transition>
    </template>
    <template #body>
      <div
        class="overflow-hidden rounded-xl border border-slate-75 dark:border-slate-700/50"
      >
        <table class="min-w-full divide-y divide-slate-75 dark:divide-slate-700">
          <thead class="bg-slate-25 dark:bg-slate-800/50">
            <tr>
              <th
                class="py-3.5 ltr:pl-4 rtl:pr-4 ltr:pr-4 rtl:pl-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-600 dark:text-slate-400"
              >
                {{ $t('AI_ATTENDANT.LIST.AGENT') }}
              </th>
              <th
                class="py-3.5 ltr:pr-4 rtl:pl-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-600 dark:text-slate-400"
              >
                {{ $t('AI_ATTENDANT.LIST.INBOX') }}
              </th>
              <th
                class="py-3.5 ltr:pr-4 rtl:pl-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-600 dark:text-slate-400"
              >
                {{ $t('AI_ATTENDANT.LIST.SCHEDULE') }}
              </th>
              <th
                class="py-3.5 ltr:pr-4 rtl:pl-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-600 dark:text-slate-400"
              >
                {{ $t('AI_ATTENDANT.LIST.STATUS') }}
              </th>
              <th
                class="py-3.5 ltr:pr-4 rtl:pl-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-600 dark:text-slate-400"
              >
                {{ $t('AI_ATTENDANT.LIST.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody
            class="divide-y divide-slate-50 dark:divide-slate-800 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-300"
          >
            <tr
              v-for="config in records"
              :key="config.id"
              class="transition-colors hover:bg-slate-25 dark:hover:bg-slate-800/40"
            >
              <td class="py-4 ltr:pl-4 rtl:pr-4 ltr:pr-4 rtl:pl-4">
                <div class="flex items-center gap-2 min-w-0">
                  <img
                    :src="avatarPreviewUrl(config.avatar_id)"
                    alt=""
                    class="w-8 h-8 rounded-full object-cover shrink-0 border border-solid border-slate-200 dark:border-slate-600"
                  />
                  <span class="font-medium text-slate-900 dark:text-slate-100 truncate">
                    {{ agentDisplayName(config) }}
                  </span>
                </div>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <span class="text-slate-800 dark:text-slate-100">
                  {{ inboxLabels(config) }}
                </span>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <span
                  class="inline-flex px-2 py-0.5 rounded-lg text-xs font-medium bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300"
                >
                  {{ scheduleLabel(config.schedule_mode) }}
                </span>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <div class="flex items-center gap-2 flex-wrap">
                  <woot-switch
                    :value="config.active"
                    :disabled="togglingId === config.id"
                    @input="toggleActive(config, $event)"
                  />
                  <span
                    class="inline-flex px-2 py-0.5 rounded-lg text-xs font-medium"
                    :class="statusBadgeClass(config)"
                  >
                    {{ statusLabel(config) }}
                  </span>
                </div>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <div class="flex justify-end items-center gap-1">
                  <woot-button
                    v-tooltip.top="$t('AI_ATTENDANT.TEST.TOOLTIP')"
                    variant="smooth"
                    size="tiny"
                    color-scheme="secondary"
                    icon="chat"
                    @click="openTestPopup(config)"
                  />
                  <router-link
                    :to="{
                      name: 'settings_ia_edit',
                      params: { configId: config.id },
                    }"
                  >
                    <woot-button
                      v-tooltip.top="$t('AI_ATTENDANT.EDIT.TOOLTIP')"
                      variant="smooth"
                      size="tiny"
                      color-scheme="secondary"
                      icon="edit"
                    />
                  </router-link>
                  <woot-button
                    v-tooltip.top="$t('AI_ATTENDANT.DELETE.TOOLTIP')"
                    variant="smooth"
                    color-scheme="alert"
                    size="tiny"
                    icon="dismiss-circle"
                    @click="openDeletePopup(config)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <woot-delete-modal
        :show.sync="showDeleteConfirmationPopup"
        :on-close="closeDeletePopup"
        :on-confirm="confirmDeletion"
        :title="$t('AI_ATTENDANT.DELETE.CONFIRM.TITLE')"
        :message="$t('AI_ATTENDANT.DELETE.CONFIRM.MESSAGE')"
        :message-value="` ${
          selectedConfig.digital_agent_name || inboxLabels(selectedConfig)
        }?`"
        :confirm-text="$t('AI_ATTENDANT.DELETE.CONFIRM.YES')"
        :reject-text="$t('AI_ATTENDANT.DELETE.CONFIRM.NO')"
      />

      <AiAttendantTestModal
        :show.sync="showTestPopup"
        :config-id="selectedConfig.id"
        :agent-name="agentDisplayName(selectedConfig)"
        :inbox-name="inboxLabels(selectedConfig)"
        :avatar-url="avatarPreviewUrl(selectedConfig.avatar_id)"
        @close="closeTestPopup"
      />
    </template>
  </SettingsLayout>
</template>
