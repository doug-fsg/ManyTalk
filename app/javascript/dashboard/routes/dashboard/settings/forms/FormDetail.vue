<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'dashboard/composables/route';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import AccountFormsAPI from 'dashboard/api/accountForms';

import FormEditorHeader from './FormEditorHeader.vue';
import FormFieldPalette from './FormFieldPalette.vue';
import FormFieldsEditor from './FormFieldsEditor.vue';
import FormPreviewPanel from './FormPreviewPanel.vue';
import FormAppearanceSettings from './FormAppearanceSettings.vue';
import AddAttribute from '../attributes/AddAttribute.vue';
import {
  isFormSupportedAttribute,
  enrichCustomField,
} from 'shared/helpers/formFieldHelpers';

// ── Router / i18n / Store ────────────────────────────────────────────────────

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

// ── State ────────────────────────────────────────────────────────────────────

const form = ref(null);
const isLoading = ref(true);
const isSaving = ref(false);
const isUpdatingStatus = ref(false);
const activeTab = ref('editor');
const submissions = ref([]);
const submissionsMeta = ref({ page: 1, total_pages: 1, total_count: 0 });
const isLoadingSubmissions = ref(false);
const isExporting = ref(false);
const selectedFieldIndex = ref(-1);
const showAddAttributeModal = ref(false);
const savedSnapshot = ref('');

const buildSnapshot = source =>
  JSON.stringify({
    name: source?.name,
    branding: source?.branding,
    settings: source?.settings,
    definition: source?.definition,
  });

const syncSnapshot = () => {
  if (form.value) savedSnapshot.value = buildSnapshot(form.value);
};

const isDirty = computed(() => {
  if (!form.value) return false;
  return buildSnapshot(form.value) !== savedSnapshot.value;
});

const formId = computed(() => Number(route.params.formId));
const accountId = computed(() => Number(route.params.accountId));

// ── Status helpers ────────────────────────────────────────────────────────────

const isPublished = computed(() => form.value?.status === 'published');
const isDraftOrPaused = computed(
  () => form.value && (form.value.status === 'draft' || form.value.status === 'paused')
);

const publicUrl = computed(() => {
  if (!form.value?.slug) return '';
  return `${window.location.origin}/public/forms/${accountId.value}/${form.value.slug}`;
});

const submissionsLabel = computed(() => {
  const count = submissionsMeta.value.total_count;
  if (!count) return t('ACCOUNT_FORM.SUBMISSIONS.EMPTY');
  return t('ACCOUNT_FORM.LIST.SUBMISSIONS_TOOLTIP', { count });
});

// ── Field management (moved from FormFieldsEditor) ───────────────────────────

const NATIVE_OPTIONS = computed(() => [
  { key: 'name', field: 'name', label: t('ACCOUNT_FORM.NATIVE.NAME'), type: 'native' },
  { key: 'email', field: 'email', label: t('ACCOUNT_FORM.NATIVE.EMAIL'), type: 'native' },
  {
    key: 'phone_number',
    field: 'phone_number',
    label: t('ACCOUNT_FORM.NATIVE.PHONE'),
    type: 'native',
  },
]);

const localFields = computed(() => form.value?.definition?.fields || []);

const paletteCustomAttributes = computed(() =>
  (getters['attributes/getAttributesByModel'].value('contact_attribute') || []).filter(
    isFormSupportedAttribute
  )
);

const usedCustomAttributeKeys = computed(() =>
  localFields.value
    .filter(f => f.type === 'custom_attribute')
    .map(f => f.attribute_key)
);

const allContactAttributes = computed(
  () => getters['attributes/getAttributesByModel'].value('contact_attribute') || []
);

const availableNative = computed(() =>
  NATIVE_OPTIONS.value.filter(opt => !localFields.value.some(f => f.field === opt.field))
);

const setFields = newFields => {
  if (!form.value) return;
  form.value.definition = { ...form.value.definition, fields: [...newFields] };
};

const addNativeField = opt => {
  setFields([
    ...localFields.value,
    { key: opt.key, type: 'native', field: opt.field, label: opt.label, required: false },
  ]);
  selectedFieldIndex.value = localFields.value.length - 1;
};

const addCustomAttribute = attr => {
  setFields([
    ...localFields.value,
    {
      key: `cf_${attr.attribute_key}`,
      type: 'custom_attribute',
      attribute_key: attr.attribute_key,
      attribute_model: 'contact_attribute',
      attribute_display_type: attr.attribute_display_type,
      attribute_values: attr.attribute_values,
      label: attr.attribute_display_name || attr.attribute_key,
      required: false,
    },
  ]);
  selectedFieldIndex.value = localFields.value.length - 1;
};

const removeField = index => {
  const updated = localFields.value.filter((_, i) => i !== index);
  setFields(updated);
  if (selectedFieldIndex.value >= updated.length) {
    selectedFieldIndex.value = updated.length - 1;
  }
};

const toggleRequired = index => {
  setFields(
    localFields.value.map((f, i) => (i === index ? { ...f, required: !f.required } : f))
  );
};

const updateFieldLabel = (index, label) => {
  setFields(
    localFields.value.map((f, i) => (i === index ? { ...f, label } : f))
  );
};

const reorderFields = newOrder => {
  setFields(newOrder);
};

const openCreateAttributeModal = () => {
  showAddAttributeModal.value = true;
};

const closeCreateAttributeModal = () => {
  showAddAttributeModal.value = false;
};

const onAttributeDeleted = attr => {
  const updated = localFields.value.filter(f => f.attribute_key !== attr.attribute_key);
  if (updated.length !== localFields.value.length) {
    setFields(updated);
  }
};

// ── API operations (unchanged from original) ─────────────────────────────────

const goBack = () => {
  if (isDirty.value && !window.confirm(t('ACCOUNT_FORM.EDITOR.UNSAVED_LEAVE_CONFIRM'))) {
    return;
  }
  router.push({ name: 'forms_list', params: { accountId: accountId.value } });
};

const enrichFormDefinitionFields = () => {
  if (!form.value?.definition?.fields?.length) return;

  const attrs =
    getters['attributes/getAttributesByModel'].value('contact_attribute') || [];

  form.value.definition = {
    ...form.value.definition,
    fields: form.value.definition.fields.map(field => enrichCustomField(field, attrs)),
  };
};

const fetchForm = async () => {
  isLoading.value = true;
  try {
    const { data } = await AccountFormsAPI.show(formId.value);
    form.value = data;
    enrichFormDefinitionFields();
    syncSnapshot();
  } catch {
    useAlert(t('ACCOUNT_FORM.LIST.FETCH_ERROR'));
    goBack();
  } finally {
    isLoading.value = false;
  }
};

const persistForm = async () => {
  const { data } = await AccountFormsAPI.update(formId.value, {
    name: form.value.name,
    branding: form.value.branding,
    settings: form.value.settings,
    definition: form.value.definition,
  });
  form.value = data;
  enrichFormDefinitionFields();
  syncSnapshot();
};

const saveForm = async () => {
  if (!form.value || !isDirty.value) return;
  isSaving.value = true;
  try {
    await persistForm();
    useAlert(t('ACCOUNT_FORM.DETAIL.SAVE_SUCCESS'));
  } catch (error) {
    const message = error?.response?.data?.message;
    useAlert(message || t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const updateStatus = async status => {
  isUpdatingStatus.value = true;
  try {
    if (status === 'published') await persistForm();
    const { data } = await AccountFormsAPI.updateStatus(formId.value, status);
    form.value = data;
    enrichFormDefinitionFields();
    syncSnapshot();
    useAlert(t('ACCOUNT_FORM.DETAIL.STATUS_SUCCESS'));
  } catch (error) {
    const message = error?.response?.data?.message;
    useAlert(message || t('ACCOUNT_FORM.DETAIL.SAVE_ERROR'));
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
  const p = page || 1;
  isLoadingSubmissions.value = true;
  try {
    const { data } = await AccountFormsAPI.getSubmissions(formId.value, { page: p });
    submissions.value = data.payload || [];
    const meta = data.meta || {};
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
    link.download = `form-${form.value ? form.value.slug : formId.value}-submissions.csv`;
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
      name: 'contact_profile_dashboard',
      params: { accountId: accountId.value, contactId },
    });
  };

const switchTab = key => {
  activeTab.value = key;
  if (key === 'submissions' && !submissions.value.length) {
    fetchSubmissions(1);
  }
};

// ── Helpers for submissions table ────────────────────────────────────────────

const submissionPayload = (row, key) => (row.payload || {})[key] || '—';
const submissionContactId = row => (row.contact ? row.contact.id : null);
const rowDate = row => new Date(row.created_at * 1000).toLocaleString();

// ── Lifecycle ────────────────────────────────────────────────────────────────

onMounted(async () => {
  await fetchForm();
  if (route.query.tab === 'submissions') {
    switchTab('submissions');
  }
  const attrs = getters['attributes/getAttributesByModel'].value('contact_attribute');
  if (!attrs || !attrs.length) {
    store.dispatch('attributes/get');
  }
});
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden bg-white dark:bg-slate-900">
    <!-- Loading state -->
    <div v-if="isLoading" class="flex flex-1 items-center justify-center">
      <woot-spinner size="" />
    </div>

    <template v-else-if="form">
      <!-- ── Header ────────────────────────────────────────────────────────── -->
      <FormEditorHeader
        :form="form"
        :active-tab="activeTab"
        :is-saving="isSaving"
        :is-dirty="isDirty"
        :is-updating-status="isUpdatingStatus"
        :is-published="isPublished"
        :is-draft-or-paused="isDraftOrPaused"
        :form-name="form.name"
        @back="goBack"
        @save="saveForm"
        @publish="updateStatus('published')"
        @pause="updateStatus('paused')"
        @copy-link="copyPublicLink"
        @open-public="openPublic"
        @tab-change="switchTab"
      />

      <!-- ── Tab: Editor (3 columns) ──────────────────────────────────────── -->
      <div
        v-show="activeTab === 'editor'"
        class="flex flex-1 min-h-0 overflow-hidden"
      >
        <!-- Left: Field palette -->
        <div class="w-60 shrink-0 hidden lg:block overflow-hidden">
          <FormFieldPalette
            :native-fields="availableNative"
            :custom-attributes="paletteCustomAttributes"
            :used-attribute-keys="usedCustomAttributeKeys"
            @add-native="addNativeField"
            @add-custom="addCustomAttribute"
            @create-attribute="openCreateAttributeModal"
            @attribute-deleted="onAttributeDeleted"
          />
        </div>

        <!-- Center: Fields editor -->
        <div class="flex-1 min-w-0 overflow-y-auto px-6 py-5">
          <!-- Mobile: add field shortcut (when palette is hidden) -->
          <div class="lg:hidden mb-4">
            <details class="border border-slate-100 dark:border-slate-700 rounded-xl overflow-hidden">
              <summary class="flex items-center gap-2 px-4 py-3 text-sm font-medium text-slate-700 dark:text-slate-200 cursor-pointer select-none bg-white dark:bg-slate-800">
                <fluent-icon icon="add-circle" size="14" aria-hidden="true" />
                {{ $t('ACCOUNT_FORM.PALETTE.MOBILE_TOGGLE') }}
              </summary>
              <div class="border-t border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800">
                <FormFieldPalette
                  :native-fields="availableNative"
                  :custom-attributes="paletteCustomAttributes"
                  :used-attribute-keys="usedCustomAttributeKeys"
                  @add-native="addNativeField"
                  @add-custom="addCustomAttribute"
                  @create-attribute="openCreateAttributeModal"
                  @attribute-deleted="onAttributeDeleted"
                />
              </div>
            </details>
          </div>

          <!-- Field list -->
          <FormFieldsEditor
            :fields="localFields"
            :selected-index="selectedFieldIndex"
            @reorder="reorderFields"
            @remove="removeField"
            @toggle-required="toggleRequired"
            @update-label="updateFieldLabel"
            @select="idx => (selectedFieldIndex = idx)"
            @sync="() => {}"
          />
        </div>

        <!-- Right: Preview -->
        <div class="w-72 shrink-0 hidden xl:block overflow-hidden">
          <FormPreviewPanel
            :branding="form.branding"
            :settings="form.settings"
            :definition="form.definition"
            :contact-attributes="allContactAttributes"
          />
        </div>
      </div>

      <!-- ── Tab: Configurações ────────────────────────────────────────────── -->
      <div
        v-show="activeTab === 'settings'"
        class="flex flex-1 min-h-0 overflow-hidden"
      >
        <!-- Left: settings form (same column structure as editor) -->
        <div class="flex-1 min-w-0 overflow-y-auto px-6 py-5">
          <div class="max-w-lg flex flex-col gap-4 pb-8">
            <FormAppearanceSettings
              :branding="form.branding"
              :account-id="accountId"
              @update:branding="val => (form.branding = val)"
            />

            <!-- Section: Conteúdo do cabeçalho -->
            <div>
              <p class="text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-3">
                {{ $t('ACCOUNT_FORM.SETTINGS_TAB.HEADER_SECTION') }}
              </p>
              <div class="bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700 rounded-xl overflow-hidden divide-y divide-slate-100 dark:divide-slate-700">
                <!-- Title -->
                <div class="px-4 py-3">
                  <label class="block text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5">
                    {{ $t('ACCOUNT_FORM.APPEARANCE.HEADER_TITLE') }}
                  </label>
                  <input
                    v-model="form.branding.header_title"
                    type="text"
                    name="header_title"
                    autocomplete="off"
                    class="w-full text-sm text-slate-800 dark:text-slate-200 bg-transparent outline-none placeholder-slate-300 dark:placeholder-slate-600 focus-visible:underline focus-visible:decoration-woot-400"
                    :placeholder="$t('ACCOUNT_FORM.APPEARANCE.HEADER_TITLE')"
                  />
                </div>
                <!-- Description -->
                <div class="px-4 py-3">
                  <label class="block text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5">
                    {{ $t('ACCOUNT_FORM.APPEARANCE.HEADER_DESCRIPTION') }}
                  </label>
                  <textarea
                    v-model="form.branding.header_description"
                    rows="2"
                    name="header_description"
                    autocomplete="off"
                    class="w-full text-sm text-slate-800 dark:text-slate-200 bg-transparent outline-none resize-none placeholder-slate-300 dark:placeholder-slate-600 focus-visible:underline focus-visible:decoration-woot-400"
                    :placeholder="$t('ACCOUNT_FORM.APPEARANCE.HEADER_DESCRIPTION')"
                  />
                </div>
              </div>
            </div>

            <!-- Section: Comportamento -->
            <div>
              <p class="text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-3">
                {{ $t('ACCOUNT_FORM.SETTINGS_TAB.BEHAVIOR_SECTION') }}
              </p>
              <div class="bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700 rounded-xl overflow-hidden">
                <div class="px-4 py-3">
                  <label class="block text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5">
                    {{ $t('ACCOUNT_FORM.APPEARANCE.CONFIRMATION_MESSAGE') }}
                  </label>
                  <textarea
                    v-model="form.settings.confirmation_message"
                    rows="2"
                    name="confirmation_message"
                    autocomplete="off"
                    class="w-full text-sm text-slate-800 dark:text-slate-200 bg-transparent outline-none resize-none placeholder-slate-300 dark:placeholder-slate-600 focus-visible:underline focus-visible:decoration-woot-400"
                    :placeholder="$t('ACCOUNT_FORM.APPEARANCE.CONFIRMATION_MESSAGE')"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Right: live preview (same column as editor tab) -->
        <div class="w-72 shrink-0 hidden xl:block overflow-hidden">
          <FormPreviewPanel
            :branding="form.branding"
            :settings="form.settings"
            :definition="form.definition"
            :contact-attributes="allContactAttributes"
          />
        </div>
      </div>

      <!-- ── Tab: Submissões ────────────────────────────────────────────────── -->
      <div
        v-show="activeTab === 'submissions'"
        class="flex flex-col flex-1 min-h-0 px-6 pt-5 overflow-hidden"
      >
        <!-- Toolbar -->
        <div class="flex items-center justify-between gap-2 mb-3 shrink-0">
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ submissionsLabel }}
          </span>
          <div class="flex items-center gap-1">
            <woot-button
              variant="smooth"
              color-scheme="secondary"
              size="tiny"
              icon="arrow-download"
              v-tooltip.top="$t('ACCOUNT_FORM.SUBMISSIONS.EXPORT_CSV_TOOLTIP')"
              :is-loading="isExporting"
              :disabled="!submissions.length"
              @click="exportCsv"
            />
            <woot-button
              variant="smooth"
              color-scheme="secondary"
              size="tiny"
              icon="chevron-left"
              v-tooltip.top="$t('ACCOUNT_FORM.SUBMISSIONS.PREV_PAGE')"
              :disabled="submissionsMeta.page <= 1"
              @click="fetchSubmissions(submissionsMeta.page - 1)"
            />
            <span
              v-if="submissionsMeta.total_pages > 1"
              class="text-xs tabular-nums text-slate-400 px-1"
            >
              {{ submissionsMeta.page }}/{{ submissionsMeta.total_pages }}
            </span>
            <woot-button
              variant="smooth"
              color-scheme="secondary"
              size="tiny"
              icon="chevron-right"
              v-tooltip.top="$t('ACCOUNT_FORM.SUBMISSIONS.NEXT_PAGE')"
              :disabled="submissionsMeta.page >= submissionsMeta.total_pages"
              @click="fetchSubmissions(submissionsMeta.page + 1)"
            />
          </div>
        </div>

        <!-- Loading -->
        <div v-if="isLoadingSubmissions" class="flex justify-center py-12">
          <woot-spinner size="" />
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
          class="flex-1 overflow-auto rounded-xl border border-slate-200 dark:border-slate-700"
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
                  <woot-button
                    v-if="submissionContactId(row)"
                    variant="smooth"
                    color-scheme="secondary"
                    size="tiny"
                    icon="person"
                    v-tooltip.top="$t('ACCOUNT_FORM.SUBMISSIONS.VIEW_CONTACT_TOOLTIP')"
                    @click="openContact(submissionContactId(row))"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <AddAttribute
      v-if="showAddAttributeModal"
      :selected-attribute-model-tab="1"
      :hide-model-and-key="true"
      :on-close="closeCreateAttributeModal"
    />
  </div>
</template>
