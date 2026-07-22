<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'dashboard/composables/route';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useI18n } from 'dashboard/composables/useI18n';
import ContactInfoPanel from '../components/ContactInfoPanel.vue';
import ContactNotes from 'dashboard/modules/notes/NotesOnContactPage.vue';
import ContactActivities from '../../crm/components/ContactActivities.vue';
import SettingsHeader from '../../settings/SettingsHeader.vue';
import Spinner from 'shared/components/Spinner.vue';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import ContactProfileHeader from '../components/profile/ContactProfileHeader.vue';
import ContactTimeline from '../components/profile/ContactTimeline.vue';
import ContactDealPanel from '../components/profile/ContactDealPanel.vue';
import { useContactCrmContext } from '../composables/useContactCrmContext';
import { useContactTimeline } from '../composables/useContactTimeline';
import {
  getActivityCountForContact,
  resolveContactProfileTabIndex,
} from '../../crm/utils/crmNavigationHelper';

const props = defineProps({
  contactId: {
    type: [String, Number],
    required: true,
  },
});

const route = useRoute();
const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const selectedTabIndex = ref(0);
const highlightActivityId = ref(null);
const contactIdRef = computed(() => Number(props.contactId));
const accountIdRef = computed(() => route.params.accountId);

const uiFlags = computed(() => getters['contacts/getUIFlags'].value);
const contact = computed(() =>
  getters['contacts/getContact'].value(props.contactId)
);

const {
  resolvedPipelineId,
  primaryPipeline,
  primaryStage,
  primaryDealValue,
  primaryAssignee,
  primaryWinLost,
  enteredAt,
  hasPipeline,
  kanbanDeepLink,
  stageColor,
} = useContactCrmContext(contact, accountIdRef);

const {
  events: timelineEvents,
  loading: timelineLoading,
  firstFormSubmission,
  fetchTimeline,
} = useContactTimeline(contactIdRef);

const pendingActivitiesCount = computed(() => {
  if (!contact.value?.id) return 0;
  return getActivityCountForContact(
    getters['activities/getPendingCountByContactId'].value,
    contact.value.id
  );
});

const overdueActivitiesCount = computed(() => {
  if (!contact.value?.id) return 0;
  return getActivityCountForContact(
    getters['activities/getOverdueCountByContactId'].value,
    contact.value.id
  );
});

const applyDefaultTab = (initialTab = null) => {
  selectedTabIndex.value = resolveContactProfileTabIndex({
    initialTab,
    hasOverdueActivities: overdueActivitiesCount.value > 0,
  });
};

const tabs = computed(() => [
  { key: 'timeline', name: t('CONTACT_PROFILE.TABS.TIMELINE') },
  { key: 'deal', name: t('CONTACT_PROFILE.TABS.DEAL') },
  { key: 'notes', name: t('CONTACT_PROFILE.TABS.NOTES') },
  { key: 'activities', name: t('CONTACT_PROFILE.TABS.ACTIVITIES') },
]);

const backUrl = computed(
  () => `/app/accounts/${route.params.accountId}/contacts`
);

const formOriginName = computed(
  () => firstFormSubmission.value?.account_form_name || null
);

const primaryPipelineName = computed(
  () => primaryPipeline.value?.attribute_display_name || null
);

const activitiesPipelineId = computed(() => {
  if (resolvedPipelineId.value) return resolvedPipelineId.value;
  return contact.value?.pipeline_positions?.[0]?.pipeline_id || null;
});

const fetchContactDetails = () => {
  store.dispatch('contacts/show', { id: props.contactId });
};

const bootstrap = async () => {
  fetchContactDetails();
  store.dispatch('attributes/get', 0);
  store.dispatch('agents/get');

  if (contact.value?.id) {
    await store.dispatch('activities/get', {
      params: { contact_id: contact.value.id },
      merge: false,
    });
  }

  await fetchTimeline();
  applyDefaultTab(route.query.tab || null);
};

onMounted(bootstrap);

watch(
  () => props.contactId,
  () => {
    highlightActivityId.value = null;
    bootstrap();
  }
);

watch(contact, async newContact => {
  if (!newContact?.id) return;
  await store.dispatch('activities/get', {
    params: { contact_id: newContact.id },
    merge: false,
  });
  applyDefaultTab();
});

const onClickTabChange = index => {
  selectedTabIndex.value = index;
};

const onOpenActivitiesFromTimeline = activityId => {
  highlightActivityId.value = activityId;
  selectedTabIndex.value = 3;
};

const onActivitiesChanged = async () => {
  await fetchTimeline();
  if (contact.value?.id) {
    await store.dispatch('activities/get', {
      params: { contact_id: contact.value.id },
      merge: false,
    });
  }
};
</script>

<template>
  <div
    class="flex justify-between flex-col h-full m-0 flex-1 bg-white dark:bg-slate-900"
  >
    <settings-header
      button-route="new"
      :header-title="contact.name"
      show-back-button
      :back-button-label="$t('CONTACT_PROFILE.BACK_BUTTON')"
      :back-url="backUrl"
      :show-new-button="false"
    >
      <thumbnail
        v-if="contact.thumbnail"
        :src="contact.thumbnail"
        :username="contact.name"
        size="32px"
        class="mr-2 rtl:mr-0 rtl:ml-2"
      />
    </settings-header>

    <div v-if="uiFlags.isFetchingItem" class="text-center p-4 text-base h-full">
      <spinner size="" />
      <span>{{ $t('CONTACT_PROFILE.LOADING') }}</span>
    </div>

    <div
      v-else-if="contact.id"
      class="overflow-hidden flex-1 min-w-0 flex flex-col"
    >
      <contact-profile-header
        :contact="contact"
        :account-id="accountIdRef"
        :primary-stage="primaryStage"
        :stage-color="stageColor"
        :primary-pipeline-name="primaryPipelineName"
        :form-origin-name="formOriginName"
        :pending-activities-count="pendingActivitiesCount"
        :overdue-activities-count="overdueActivitiesCount"
        :has-pipeline="hasPipeline"
        :kanban-deep-link="kanbanDeepLink"
      />

      <div
        class="overflow-hidden flex flex-wrap ml-auto mr-auto max-w-full flex-1 min-h-0 w-full"
      >
        <contact-info-panel
          :show-close-button="false"
          :show-avatar="false"
          :contact="contact"
        />

        <div class="w-3/4 h-full min-h-0 flex flex-col">
          <woot-tabs :index="selectedTabIndex" @change="onClickTabChange">
            <woot-tabs-item
              v-for="tab in tabs"
              :key="tab.key"
              :name="tab.name"
              :show-badge="false"
            />
          </woot-tabs>

          <div
            class="bg-slate-25 dark:bg-slate-800 flex-1 min-h-0 p-4 overflow-auto"
          >
            <contact-timeline
              v-if="selectedTabIndex === 0"
              :contact-id="contactIdRef"
              :account-id="accountIdRef"
              :highlight-pipeline-id="resolvedPipelineId"
              :external-events="timelineEvents"
              :external-loading="timelineLoading"
              @open-activities="onOpenActivitiesFromTimeline"
              @refresh="fetchTimeline"
            />

            <contact-deal-panel
              v-else-if="selectedTabIndex === 1"
              :contact="contact"
              :account-id="accountIdRef"
              :primary-pipeline-name="primaryPipelineName"
              :primary-stage="primaryStage"
              :stage-color="stageColor"
              :primary-deal-value="primaryDealValue"
              :primary-assignee="primaryAssignee"
              :primary-win-lost="primaryWinLost"
              :entered-at="enteredAt"
              :has-pipeline="hasPipeline"
              :kanban-deep-link="kanbanDeepLink"
              :resolved-pipeline-id="resolvedPipelineId"
            />

            <contact-notes
              v-else-if="selectedTabIndex === 2"
              :contact-id="contactIdRef"
            />

            <contact-activities
              v-else-if="selectedTabIndex === 3 && activitiesPipelineId"
              :contact-id="contactIdRef"
              :contact="contact"
              :pipeline-id="activitiesPipelineId"
              :highlight-activity-id="highlightActivityId"
              @changed="onActivitiesChanged"
            />

            <div
              v-else-if="selectedTabIndex === 3"
              class="rounded-xl border border-dashed border-slate-300 px-4 py-8 text-center dark:border-slate-600"
            >
              <p class="text-sm text-slate-600 dark:text-slate-300">
                {{ $t('CONTACT_PROFILE.DEAL.NO_PIPELINE_HINT') }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
