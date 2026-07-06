<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import FormStatusBadge from './FormStatusBadge.vue';

const props = defineProps({
  form: { type: Object, default: null },
  activeTab: { type: String, default: 'editor' },
  isSaving: { type: Boolean, default: false },
  isDirty: { type: Boolean, default: false },
  isUpdatingStatus: { type: Boolean, default: false },
  isPublished: { type: Boolean, default: false },
  isDraftOrPaused: { type: Boolean, default: false },
  formName: { type: String, default: '' },
});

const emit = defineEmits([
  'back',
  'save',
  'publish',
  'pause',
  'copy-link',
  'open-public',
  'tab-change',
]);

const { t } = useI18n();
const showActionsMenu = ref(false);

const saveStatus = computed(() => {
  if (props.isSaving) return 'saving';
  if (props.isDirty) return 'unsaved';
  return 'saved';
});

const saveStatusLabel = computed(() => {
  const labels = {
    saving: t('ACCOUNT_FORM.EDITOR.SAVING'),
    unsaved: t('ACCOUNT_FORM.EDITOR.UNSAVED'),
    saved: t('ACCOUNT_FORM.EDITOR.SAVED'),
  };
  return labels[saveStatus.value];
});

const saveButtonTooltip = computed(() =>
  props.isDirty
    ? t('ACCOUNT_FORM.DETAIL.SAVE_TOOLTIP')
    : t('ACCOUNT_FORM.EDITOR.SAVE_UP_TO_DATE_TOOLTIP')
);

const tabs = computed(() => [
  { key: 'editor', label: t('ACCOUNT_FORM.TABS.EDITOR'), icon: 'edit' },
  { key: 'settings', label: t('ACCOUNT_FORM.TABS.SETTINGS'), icon: 'settings' },
  { key: 'submissions', label: t('ACCOUNT_FORM.TABS.SUBMISSIONS'), icon: 'people' },
]);

const closeMenu = () => {
  showActionsMenu.value = false;
};

const handleCopyLink = () => {
  emit('copy-link');
  closeMenu();
};

const handleOpenPublic = () => {
  emit('open-public');
  closeMenu();
};
</script>

<template>
  <header class="shrink-0 bg-white dark:bg-slate-900 border-b border-slate-100 dark:border-slate-800">
    <div class="flex items-center justify-between gap-4 px-5 pt-4 pb-3">
      <nav
        class="flex items-center gap-1.5 text-xs min-w-0"
        :aria-label="$t('ACCOUNT_FORM.EDITOR.NAV_LABEL')"
      >
        <button
          type="button"
          class="text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300 transition-colors duration-150 shrink-0"
          @click="emit('back')"
        >
          {{ $t('ACCOUNT_FORM.EDITOR.BREADCRUMB') }}
        </button>
        <fluent-icon
          icon="chevron-right"
          size="10"
          class="text-slate-300 dark:text-slate-600 shrink-0"
          aria-hidden="true"
        />
        <span
          class="text-slate-700 dark:text-slate-200 font-medium truncate"
          :title="formName"
        >
          {{ formName || $t('ACCOUNT_FORM.EDITOR.LOADING') }}
        </span>
        <span
          class="text-xs whitespace-nowrap select-none shrink-0"
          aria-live="polite"
          aria-atomic="true"
        >
          <span
            v-if="saveStatus === 'saving'"
            class="inline-flex items-center gap-1 text-slate-400 dark:text-slate-500"
          >
            <span
              class="w-3 h-3 border border-woot-400 border-t-transparent rounded-full animate-spin"
              aria-hidden="true"
            />
            {{ saveStatusLabel }}
          </span>
          <span
            v-else-if="saveStatus === 'unsaved'"
            class="text-amber-600 dark:text-amber-400"
          >
            {{ saveStatusLabel }}
          </span>
          <span v-else class="text-slate-400 dark:text-slate-500">
            {{ saveStatusLabel }}
          </span>
        </span>
      </nav>

      <div class="flex items-center gap-2 shrink-0">
        <FormStatusBadge
          v-if="form"
          :status="form.status"
          pill
        />

        <woot-button
          v-tooltip.bottom="{ content: $t('ACCOUNT_FORM.EDITOR.COPY_LINK_TOOLTIP'), delay: { show: 300 } }"
          variant="smooth"
          color-scheme="secondary"
          size="small"
          icon="copy"
          @click="emit('copy-link')"
        />

        <woot-button
          v-if="isDraftOrPaused"
          v-tooltip.bottom="{ content: $t('ACCOUNT_FORM.EDITOR.PUBLISH_TOOLTIP'), delay: { show: 300 } }"
          variant="smooth"
          color-scheme="success"
          size="small"
          icon="play-circle"
          :is-loading="isUpdatingStatus"
          @click="emit('publish')"
        />
        <woot-button
          v-else-if="isPublished"
          v-tooltip.bottom="{ content: $t('ACCOUNT_FORM.EDITOR.PAUSE_TOOLTIP'), delay: { show: 300 } }"
          variant="smooth"
          color-scheme="secondary"
          size="small"
          icon="microphone-pause"
          :is-loading="isUpdatingStatus"
          @click="emit('pause')"
        />

        <div class="relative">
          <woot-button
            v-tooltip.bottom="{ content: $t('ACCOUNT_FORM.EDITOR.MORE_OPTIONS'), delay: { show: 300 } }"
            variant="smooth"
            color-scheme="secondary"
            size="small"
            icon="more-vertical"
            @click="showActionsMenu = !showActionsMenu"
          />

          <div
            v-if="showActionsMenu"
            v-on-clickaway="closeMenu"
            class="absolute right-0 top-full mt-1 z-20 w-48 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-lg py-1 overflow-hidden"
          >
            <button
              type="button"
              class="flex items-center gap-2.5 w-full px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-100"
              @click="handleOpenPublic"
            >
              <fluent-icon icon="open" size="14" class="text-slate-400" aria-hidden="true" />
              {{ $t('ACCOUNT_FORM.EDITOR.OPEN_PUBLIC') }}
            </button>
            <button
              type="button"
              class="flex items-center gap-2.5 w-full px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-100"
              @click="handleCopyLink"
            >
              <fluent-icon icon="link" size="14" class="text-slate-400" aria-hidden="true" />
              {{ $t('ACCOUNT_FORM.EDITOR.COPY_PUBLIC_LINK') }}
            </button>
          </div>
        </div>

        <woot-button
          v-tooltip.bottom="{
            content: saveButtonTooltip,
            delay: { show: 300 },
          }"
          size="small"
          :variant="isDirty ? 'solid' : 'smooth'"
          :color-scheme="isDirty ? 'primary' : 'secondary'"
          :is-loading="isSaving"
          :is-disabled="!isDirty"
          icon="save"
          @click="emit('save')"
        >
          {{ $t('ACCOUNT_FORM.DETAIL.SAVE') }}
        </woot-button>
      </div>
    </div>

    <div class="flex items-end gap-0 px-5">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        type="button"
        class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition-colors duration-150 border-b-2 -mb-px cursor-pointer"
        :class="
          activeTab === tab.key
            ? 'border-woot-500 text-woot-600 dark:text-white'
            : 'border-transparent text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'
        "
        @click="emit('tab-change', tab.key)"
      >
        <fluent-icon :icon="tab.icon" size="13" aria-hidden="true" />
        {{ tab.label }}
      </button>
    </div>
  </header>
</template>
