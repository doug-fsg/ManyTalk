<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useAlert } from 'dashboard/composables';
import FormIconButton from './FormIconButton.vue';

const props = defineProps({
  form: { type: Object, required: true },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['open', 'publish', 'pause', 'delete']);

const { t } = useI18n();

const statusKey = computed(() => `ACCOUNT_FORM.STATUS.${props.form.status.toUpperCase()}`);

const statusClass = computed(() => {
  switch (props.form.status) {
    case 'published':
      return 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300';
    case 'paused':
      return 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300';
    default:
      return 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300';
  }
});

const copyLink = async () => {
  if (props.form.status !== 'published') return;
  try {
    await navigator.clipboard.writeText(props.form.public_url);
    useAlert(t('ACCOUNT_FORM.LIST.COPY_SUCCESS'));
  } catch {
    useAlert(props.form.public_url);
  }
};

const openPublic = () => {
  if (props.form.public_url) {
    window.open(props.form.public_url, '_blank', 'noopener,noreferrer');
  }
};

const submissionsTooltip = computed(() =>
  t('ACCOUNT_FORM.LIST.SUBMISSIONS_TOOLTIP', { count: props.form.submissions_count || 0 })
);
</script>

<template>
  <div
    class="flex flex-col p-5 bg-white border border-solid rounded-xl dark:bg-slate-800 border-slate-75 dark:border-slate-700/50 shadow-soft hover:shadow-soft-lg transition-all duration-300 ease-smooth"
  >
    <div class="flex items-start justify-between gap-3 mb-3">
      <button
        type="button"
        class="text-left min-w-0 flex-1 cursor-pointer"
        @click="emit('open')"
      >
        <span
          class="inline-flex items-center px-2 py-0.5 mb-2 text-xs font-medium rounded-md"
          :class="statusClass"
        >
          {{ $t(statusKey) }}
        </span>
        <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100 truncate">
          {{ form.name }}
        </h3>
      </button>
    </div>

    <div
      v-tooltip.top="{ content: submissionsTooltip, delay: { show: 200, hide: 0 } }"
      class="flex items-center gap-1.5 mb-3 cursor-default"
    >
      <fluent-icon icon="people" size="14" class="text-slate-400 dark:text-slate-500" aria-hidden="true" />
      <span class="text-sm font-medium text-slate-700 dark:text-slate-300">{{ form.submissions_count || 0 }}</span>
      <span
        v-if="form.status === 'published' && form.public_url"
        class="text-slate-200 dark:text-slate-700 mx-1"
        aria-hidden="true"
      >·</span>
      <span
        v-if="form.status === 'published' && form.public_url"
        v-tooltip.top="{ content: form.public_url, delay: { show: 200, hide: 0 } }"
        class="inline-flex items-center gap-1 text-xs text-slate-400 dark:text-slate-500 truncate max-w-[160px]"
      >
        <fluent-icon icon="link" size="12" aria-hidden="true" />
        <span class="truncate">{{ form.public_url.replace(/^https?:\/\//, '') }}</span>
      </span>
    </div>

    <div class="flex items-center gap-1 mt-auto pt-3 border-t border-slate-50 dark:border-slate-700/50">
      <FormIconButton
        v-if="form.status === 'published'"
        icon="link"
        :tooltip="$t('ACCOUNT_FORM.LIST.COPY_LINK_TOOLTIP')"
        @click="copyLink"
      />
      <FormIconButton
        v-if="form.status !== 'published'"
        icon="play-circle"
        color-scheme="primary"
        :tooltip="$t('ACCOUNT_FORM.DETAIL.PUBLISH_TOOLTIP')"
        :is-loading="loading"
        @click="emit('publish')"
      />
      <FormIconButton
        v-if="form.status === 'published'"
        icon="microphone-pause"
        :tooltip="$t('ACCOUNT_FORM.DETAIL.PAUSE_TOOLTIP')"
        :is-loading="loading"
        @click="emit('pause')"
      />
      <FormIconButton
        v-if="form.status === 'published'"
        icon="open"
        :tooltip="$t('ACCOUNT_FORM.LIST.OPEN_PUBLIC_TOOLTIP')"
        @click="openPublic"
      />
      <FormIconButton
        icon="edit"
        :tooltip="$t('ACCOUNT_FORM.DETAIL.SAVE_TOOLTIP')"
        @click="emit('open')"
      />
      <FormIconButton
        icon="dismiss-circle"
        color-scheme="alert"
        :tooltip="$t('ACCOUNT_FORM.LIST.DELETE_TOOLTIP')"
        :is-loading="loading"
        @click="emit('delete')"
      />
    </div>
  </div>
</template>
