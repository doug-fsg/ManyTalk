<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'dashboard/composables/route';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import AccountFormsAPI from 'dashboard/api/accountForms';
import FormFieldsEditor from './FormFieldsEditor.vue';
import FormPublicPreview from './FormPublicPreview.vue';
import FormIconButton from './FormIconButton.vue';
import FormLogoUpload from './FormLogoUpload.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const form = ref(null);
const isLoading = ref(true);
const isSaving = ref(false);
const isUpdatingStatus = ref(false);
const activeTab = ref('general');
const submissions = ref([]);
const submissionsMeta = ref({ page: 1, total_pages: 1, total_count: 0 });
const isLoadingSubmissions = ref(false);
const isExporting = ref(false);

const formId = computed(() => Number(route.params.formId));
const accountId = computed(() => Number(route.params.accountId));

const isPublished = computed(() => form.value && form.value.status === 'published');
const isDraftOrPaused = computed(
  () => form.value && (form.value.status === 'draft' || form.value.status === 'paused')
);

const statusLabel = computed(() => {
  if (!form.value) return '';
  const map = {
    draft: t('ACCOUNT_FORM.STATUS.DRAFT'),
    published: t('ACCOUNT_FORM.STATUS.PUBLISHED'),
    paused: t('ACCOUNT_FORM.STATUS.PAUSED'),
  };
  return map[form.value.status] || form.value.status;
});

const statusClass = computed(() => {
  if (!form.value) return 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-300';
  const map = {
    published: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    paused: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
    draft: 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-300',
  };
  return map[form.value.status] || 'bg-slate-100 text-slate-500';
});

const publicUrl = computed(() => {
  if (!form.value || !form.value.slug) return '';
  return (
    window.location.origin +
    '/public/forms/' +
    accountId.value +
    '/' +
    form.value.slug
  );
});

const submissionsLabel = computed(() => {
  const count = submissionsMeta.value.total_count;
  if (!count) return t('ACCOUNT_FORM.SUBMISSIONS.EMPTY');
  return t('ACCOUNT_FORM.LIST.SUBMISSIONS_TOOLTIP', { count: count });
});

// ── API ──────────────────────────────────────────────────────────────────────

const goBack = () => {
  router.push({ name: 'forms_list', params: { accountId: accountId.value } });
};

const fetchForm = async () => {
  isLoading.value = true;
  try {
    const { data } = await AccountFormsAPI.show(formId.value);
    form.value = data;
  } catch {
    useAlert(t('ACCOUNT_FORM.LIST.FETCH_ERROR'));
    goBack();
  } finally {
    isLoading.value = false;
  }
};

const saveForm = async () => {
  if (!form.value) return;
  isSaving.value = true;
  try {
    const { data } = await AccountFormsAPI.update(formId.value, {
      name: form.value.name,
      branding: form.value.branding,
      settings: form.value.settings,
      definition: form.value.definition,
    });
    form.value = data;
    useAlert(t('ACCOUNT_FORM.DETAIL.SAVE_SUCCESS'));
  } catch {
    useAlert(t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const updateStatus = async status => {
  isUpdatingStatus.value = true;
  try {
    const { data } = await AccountFormsAPI.updateStatus(formId.value, status);
    form.value = data;
    useAlert(t('ACCOUNT_FORM.DETAIL.STATUS_SUCCESS'));
  } catch {
    useAlert(t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
  } finally {
    isUpdatingStatus.value = false;
  }
};

const copyPublicLink = async () => {
  try {
    await navigator.clipboard.writeText(publicUrl.value);
    useAlert(t('ACCOUNT_FORM.LIST.COPY_SUCCESS'));
  } catch {
    useAlert(t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
  }
};

const openPublic = () => {
  if (publicUrl.value) window.open(publicUrl.value, '_blank', 'noopener');
};

const fetchSubmissions = async page => {
  var p = page || 1;
  isLoadingSubmissions.value = true;
  try {
    const { data } = await AccountFormsAPI.getSubmissions(formId.value, { page: p });
    submissions.value = data.payload || [];
    var meta = data.meta || {};
    submissionsMeta.value = {
      page: meta.current_page || p,
      total_pages: meta.total_pages || 1,
      total_count: meta.total_count || 0,
    };
  } catch {
    submissions.value = [];
  } finally {
    isLoadingSubmissions.value = false;
  }
};

const exportCsv = async () => {
  isExporting.value = true;
  try {
    const response = await AccountFormsAPI.exportSubmissions(formId.value);
    const blob = new Blob([response.data], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'form-' + (form.value ? form.value.slug : formId.value) + '-submissions.csv';
    link.click();
    window.URL.revokeObjectURL(url);
  } catch {
    useAlert(t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
  } finally {
    isExporting.value = false;
  }
};

const openContact = contactId => {
  router.push({
    name: 'contact_profile',
    params: { accountId: accountId.value, contactId: contactId },
  });
};

const updateDefinition = val => {
  if (form.value) form.value.definition = val;
};

const submissionPayload = (row, key) => {
  var payload = row.payload || {};
  return payload[key] || '—';
};

const submissionContactId = row => (row.contact ? row.contact.id : null);

const rowDate = row => new Date(row.created_at * 1000).toLocaleString();

const switchTab = key => {
  activeTab.value = key;
  if (key === 'submissions' && !submissions.value.length) {
    fetchSubmissions(1);
  }
};

onMounted(fetchForm);
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden">
    <!-- Loading -->
    <div v-if="isLoading" class="flex flex-1 items-center justify-center">
      <spinner size="" />
    </div>

    <template v-else-if="form">
      <!-- ── Header ──────────────────────────────────────────────────────── -->
      <div
        class="flex items-center gap-2 pb-3 mb-0 shrink-0 border-b border-slate-100 dark:border-slate-800"
      >
        <FormIconButton
          icon="chevron-left"
          :tooltip="$t('ACCOUNT_FORM.DETAIL.BACK_TOOLTIP')"
          @click="goBack"
        />

        <h1
          class="flex-1 min-w-0 text-sm font-semibold text-slate-800 dark:text-slate-100 truncate"
        >
          {{ form.name }}
        </h1>

        <span
          class="shrink-0 px-2 py-0.5 text-xs font-medium rounded-full"
          :class="statusClass"
        >
          {{ statusLabel }}
        </span>

        <!-- Publish / Pause -->
        <FormIconButton
          v-if="isDraftOrPaused"
          icon="play-circle"
          color-scheme="success"
          :tooltip="$t('ACCOUNT_FORM.DETAIL.PUBLISH_TOOLTIP')"
          :is-loading="isUpdatingStatus"
          @click="updateStatus('published')"
        />
        <FormIconButton
          v-if="isPublished"
          icon="microphone-pause"
          :tooltip="$t('ACCOUNT_FORM.DETAIL.PAUSE_TOOLTIP')"
          :is-loading="isUpdatingStatus"
          @click="updateStatus('paused')"
        />

        <span class="w-px h-4 bg-slate-200 dark:bg-slate-700 shrink-0" />

        <!-- Share -->
        <FormIconButton
          icon="copy"
          :tooltip="$t('ACCOUNT_FORM.DETAIL.COPY_LINK_TOOLTIP')"
          @click="copyPublicLink"
        />
        <FormIconButton
          v-if="isPublished"
          icon="open"
          :tooltip="$t('ACCOUNT_FORM.DETAIL.OPEN_PUBLIC_TOOLTIP')"
          @click="openPublic"
        />

        <span class="w-px h-4 bg-slate-200 dark:bg-slate-700 shrink-0" />

        <!-- Save -->
        <FormIconButton
          icon="save"
          color-scheme="primary"
          :tooltip="$t('ACCOUNT_FORM.DETAIL.SAVE_TOOLTIP')"
          :is-loading="isSaving"
          @click="saveForm"
        />
      </div>

      <!-- ── Tabs ───────────────────────────────────────────────────────── -->
      <div class="flex gap-0 shrink-0 border-b border-slate-100 dark:border-slate-800">
        <button
          type="button"
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition-colors duration-150 cursor-pointer border-b-2 -mb-px"
          :class="
            activeTab === 'general'
              ? 'border-woot-500 text-woot-600 dark:text-woot-400'
              : 'border-transparent text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'
          "
          @click="switchTab('general')"
        >
          <fluent-icon icon="settings" size="13" />
          {{ $t('ACCOUNT_FORM.TABS.GENERAL') }}
        </button>
        <button
          type="button"
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition-colors duration-150 cursor-pointer border-b-2 -mb-px"
          :class="
            activeTab === 'appearance'
              ? 'border-woot-500 text-woot-600 dark:text-woot-400'
              : 'border-transparent text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'
          "
          @click="switchTab('appearance')"
        >
          <fluent-icon icon="image" size="13" />
          {{ $t('ACCOUNT_FORM.TABS.APPEARANCE') }}
        </button>
        <button
          type="button"
          class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition-colors duration-150 cursor-pointer border-b-2 -mb-px"
          :class="
            activeTab === 'submissions'
              ? 'border-woot-500 text-woot-600 dark:text-woot-400'
              : 'border-transparent text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'
          "
          @click="switchTab('submissions')"
        >
          <fluent-icon icon="people" size="13" />
          {{ $t('ACCOUNT_FORM.TABS.SUBMISSIONS') }}
        </button>
      </div>

      <!-- ── Tab: General ───────────────────────────────────────────────── -->
      <div
        v-show="activeTab === 'general'"
        class="flex flex-1 gap-6 pt-4 min-h-0"
      >
        <div class="flex flex-col flex-1 gap-4 min-w-0 overflow-y-auto">
          <!-- Public URL (readonly) -->
          <div
            class="flex items-center gap-2 px-2 py-1.5 text-xs rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
          >
            <fluent-icon icon="globe" size="13" class="text-slate-400 shrink-0" />
            <span class="flex-1 min-w-0 text-slate-500 dark:text-slate-400 truncate">
              {{ publicUrl }}
            </span>
          </div>

          <FormFieldsEditor
            :value="form.definition"
            @input="updateDefinition"
          />
        </div>

        <!-- Live preview -->
        <div class="hidden xl:flex xl:flex-col xl:w-72 xl:shrink-0">
          <p class="mb-2 text-xs font-medium text-slate-400">
            {{ $t('ACCOUNT_FORM.APPEARANCE.PREVIEW') }}
          </p>
          <FormPublicPreview
            :branding="form.branding"
            :settings="form.settings"
            :definition="form.definition"
          />
        </div>
      </div>

      <!-- ── Tab: Appearance ────────────────────────────────────────────── -->
      <div
        v-show="activeTab === 'appearance'"
        class="flex flex-1 gap-6 pt-4 min-h-0"
      >
        <div class="flex flex-col flex-1 gap-5 min-w-0 overflow-y-auto">
          <!-- Primary color -->
          <div class="flex items-center gap-4">
            <label
              class="w-32 shrink-0 text-xs text-slate-500 dark:text-slate-400"
            >
              {{ $t('ACCOUNT_FORM.APPEARANCE.PRIMARY_COLOR') }}
            </label>
            <woot-color-picker v-model="form.branding.primary_color" />
          </div>

          <!-- Logo -->
          <div class="flex items-start gap-4">
            <label
              class="w-32 shrink-0 text-xs text-slate-500 dark:text-slate-400 mt-2"
            >
              Logo
            </label>
            <FormLogoUpload
              :value="form.branding.logo_url"
              :account-id="accountId"
              @input="val => { form.branding.logo_url = val }"
            />
          </div>

          <!-- Header title -->
          <div class="flex items-center gap-4">
            <label
              class="w-32 shrink-0 text-xs text-slate-500 dark:text-slate-400"
            >
              {{ $t('ACCOUNT_FORM.APPEARANCE.HEADER_TITLE') }}
            </label>
            <input
              v-model="form.branding.header_title"
              type="text"
              class="flex-1 px-3 py-1.5 text-sm rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-200 outline-none focus:ring-1 focus:ring-woot-500"
              :placeholder="$t('ACCOUNT_FORM.APPEARANCE.HEADER_TITLE')"
            />
          </div>

          <!-- Header description -->
          <div class="flex items-start gap-4">
            <label
              class="w-32 shrink-0 text-xs text-slate-500 dark:text-slate-400 mt-1.5"
            >
              {{ $t('ACCOUNT_FORM.APPEARANCE.HEADER_DESCRIPTION') }}
            </label>
            <textarea
              v-model="form.branding.header_description"
              rows="2"
              class="flex-1 px-3 py-1.5 text-sm rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-200 outline-none resize-none focus:ring-1 focus:ring-woot-500"
              :placeholder="$t('ACCOUNT_FORM.APPEARANCE.HEADER_DESCRIPTION')"
            />
          </div>

          <!-- Confirmation message -->
          <div class="flex items-start gap-4">
            <label
              class="w-32 shrink-0 text-xs text-slate-500 dark:text-slate-400 mt-1.5"
            >
              {{ $t('ACCOUNT_FORM.APPEARANCE.CONFIRMATION_MESSAGE') }}
            </label>
            <textarea
              v-model="form.settings.confirmation_message"
              rows="2"
              class="flex-1 px-3 py-1.5 text-sm rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-200 outline-none resize-none focus:ring-1 focus:ring-woot-500"
              :placeholder="$t('ACCOUNT_FORM.APPEARANCE.CONFIRMATION_MESSAGE')"
            />
          </div>
        </div>

        <!-- Live preview -->
        <div class="hidden xl:flex xl:flex-col xl:w-72 xl:shrink-0">
          <p class="mb-2 text-xs font-medium text-slate-400">
            {{ $t('ACCOUNT_FORM.APPEARANCE.PREVIEW') }}
          </p>
          <FormPublicPreview
            :branding="form.branding"
            :settings="form.settings"
            :definition="form.definition"
          />
        </div>
      </div>

      <!-- ── Tab: Submissions ───────────────────────────────────────────── -->
      <div
        v-show="activeTab === 'submissions'"
        class="flex flex-col flex-1 min-h-0 pt-4 overflow-hidden"
      >
        <!-- Toolbar -->
        <div class="flex items-center justify-between gap-2 mb-3 shrink-0">
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ submissionsLabel }}
          </span>
          <div class="flex items-center gap-1">
            <FormIconButton
              icon="arrow-download"
              :tooltip="$t('ACCOUNT_FORM.SUBMISSIONS.EXPORT_CSV_TOOLTIP')"
              :is-loading="isExporting"
              :disabled="!submissions.length"
              @click="exportCsv"
            />
            <FormIconButton
              icon="chevron-left"
              :tooltip="$t('ACCOUNT_FORM.SUBMISSIONS.PREV_PAGE')"
              :disabled="submissionsMeta.page <= 1"
              @click="fetchSubmissions(submissionsMeta.page - 1)"
            />
            <span
              v-if="submissionsMeta.total_pages > 1"
              class="text-xs tabular-nums text-slate-400 px-1"
            >
              {{ submissionsMeta.page }}/{{ submissionsMeta.total_pages }}
            </span>
            <FormIconButton
              icon="chevron-right"
              :tooltip="$t('ACCOUNT_FORM.SUBMISSIONS.NEXT_PAGE')"
              :disabled="submissionsMeta.page >= submissionsMeta.total_pages"
              @click="fetchSubmissions(submissionsMeta.page + 1)"
            />
          </div>
        </div>

        <!-- Loading -->
        <div v-if="isLoadingSubmissions" class="flex justify-center py-12">
          <spinner size="" />
        </div>

        <!-- Empty state -->
        <div
          v-else-if="!submissions.length"
          class="flex flex-col items-center justify-center flex-1 gap-2 text-center"
        >
          <fluent-icon
            icon="mail-inbox"
            size="28"
            class="text-slate-300 dark:text-slate-600"
            aria-hidden="true"
          />
          <p class="text-xs text-slate-400">
            {{ $t('ACCOUNT_FORM.SUBMISSIONS.EMPTY') }}
          </p>
          <p class="text-xs text-slate-300 dark:text-slate-600">
            {{ $t('ACCOUNT_FORM.SUBMISSIONS.EMPTY_HINT') }}
          </p>
        </div>

        <!-- Table -->
        <div
          v-else
          class="flex-1 overflow-auto rounded-lg border border-slate-200 dark:border-slate-700"
        >
          <table class="w-full text-sm">
            <thead
              class="sticky top-0 bg-slate-50 dark:bg-slate-800 text-slate-500 dark:text-slate-400"
            >
              <tr>
                <th class="px-3 py-2 font-medium text-left text-xs">
                  {{ $t('ACCOUNT_FORM.SUBMISSIONS.DATE') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-xs">
                  {{ $t('ACCOUNT_FORM.SUBMISSIONS.NAME') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-xs">
                  {{ $t('ACCOUNT_FORM.SUBMISSIONS.EMAIL') }}
                </th>
                <th class="px-3 py-2 font-medium text-left text-xs">
                  {{ $t('ACCOUNT_FORM.SUBMISSIONS.PHONE') }}
                </th>
                <th class="px-3 py-2 w-10" />
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in submissions"
                :key="row.id"
                class="border-t border-slate-100 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors duration-150"
              >
                <td class="px-3 py-2 text-xs text-slate-500 whitespace-nowrap">
                  {{ rowDate(row) }}
                </td>
                <td class="px-3 py-2 text-slate-800 dark:text-slate-200">
                  {{ submissionPayload(row, 'name') }}
                </td>
                <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
                  {{ submissionPayload(row, 'email') }}
                </td>
                <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
                  {{ submissionPayload(row, 'phone_number') }}
                </td>
                <td class="px-3 py-2">
                  <FormIconButton
                    v-if="submissionContactId(row)"
                    icon="person"
                    :tooltip="$t('ACCOUNT_FORM.SUBMISSIONS.VIEW_CONTACT_TOOLTIP')"
                    @click="openContact(submissionContactId(row))"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>
