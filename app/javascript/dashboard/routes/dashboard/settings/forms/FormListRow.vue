<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useAlert } from 'dashboard/composables';
import {
  formatListDate,
  formatListDateTime,
} from 'dashboard/helper/localeDateHelper';
import FormStatusBadge from './FormStatusBadge.vue';
import FormWorkflowLinkageCell from './FormWorkflowLinkageCell.vue';

const props = defineProps({
  form: { type: Object, required: true },
  linkage: { type: Object, required: true },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['open', 'publish', 'pause', 'delete', 'connect', 'submissions']);

const { t, locale } = useI18n();

const readableDate = date => formatListDate(date, locale.value);
const readableDateWithTime = date => formatListDateTime(date, locale.value);

const submissionsTooltip = computed(() =>
  t('ACCOUNT_FORM.LIST.SUBMISSIONS_TOOLTIP', {
    count: props.form.submissions_count || 0,
  })
);

const publicLinkLabel = computed(() => {
  if (!props.form.public_url) return props.form.slug || '—';
  return props.form.public_url.replace(/^https?:\/\//, '');
});

const copyLink = async () => {
  if (props.form.status !== 'published' || !props.form.public_url) return;
  try {
    await navigator.clipboard.writeText(props.form.public_url);
    useAlert(t('ACCOUNT_FORM.LIST.COPY_SUCCESS'));
  } catch {
    useAlert(props.form.public_url);
  }
};

const openSubmissions = () => {
  emit('submissions');
};
</script>

<template>
  <tr>
    <td class="py-4 ltr:pr-4 rtl:pl-4 min-w-[200px]">
      <button
        type="button"
        class="text-left font-medium text-slate-800 dark:text-slate-100 hover:text-woot-600 dark:hover:text-woot-400 transition-colors duration-200 cursor-pointer truncate max-w-[220px]"
        @click="emit('open')"
      >
        {{ form.name }}
      </button>
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      <FormStatusBadge :status="form.status" />
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      <FormWorkflowLinkageCell
        :form="form"
        :linkage="linkage"
        @connect="emit('connect')"
      />
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      <button
        type="button"
        v-tooltip.top="submissionsTooltip"
        class="text-sm font-medium text-woot-600 dark:text-woot-400 hover:text-woot-700 dark:hover:text-woot-300 transition-colors duration-200 cursor-pointer tabular-nums"
        @click="openSubmissions"
      >
        {{ form.submissions_count || 0 }}
      </button>
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4 min-w-[140px]">
      <a
        v-if="form.status === 'published' && form.public_url"
        :href="form.public_url"
        target="_blank"
        rel="noopener noreferrer"
        v-tooltip.top="form.public_url"
        class="inline-flex items-center gap-1 text-xs text-woot-600 dark:text-woot-400 hover:text-woot-700 dark:hover:text-woot-300 truncate max-w-[180px] transition-colors duration-200 cursor-pointer"
      >
        <fluent-icon icon="link" size="12" aria-hidden="true" />
        <span class="truncate">{{ publicLinkLabel }}</span>
      </a>
      <span v-else class="text-xs text-slate-400 dark:text-slate-500">
        {{ form.slug || '—' }}
      </span>
    </td>
    <td
      class="py-4 ltr:pr-4 rtl:pl-4 hidden md:table-cell min-w-[12px]"
      :title="form.updated_on ? readableDateWithTime(form.updated_on) : ''"
    >
      {{ form.updated_on ? readableDate(form.updated_on) : '—' }}
    </td>
    <td class="py-4 min-w-xs">
      <div class="flex gap-1 justify-end flex-shrink-0">
        <woot-button
          v-if="form.status === 'published'"
          v-tooltip.top="$t('ACCOUNT_FORM.LIST.COPY_LINK_TOOLTIP')"
          variant="smooth"
          size="tiny"
          color-scheme="secondary"
          class-names="grey-btn"
          icon="link"
          @click="copyLink"
        />
        <woot-button
          v-if="form.status !== 'published'"
          v-tooltip.top="$t('ACCOUNT_FORM.DETAIL.PUBLISH_TOOLTIP')"
          variant="smooth"
          size="tiny"
          color-scheme="primary"
          class-names="grey-btn"
          icon="play-circle"
          :is-loading="loading"
          @click="emit('publish')"
        />
        <woot-button
          v-if="form.status === 'published'"
          v-tooltip.top="$t('ACCOUNT_FORM.DETAIL.PAUSE_TOOLTIP')"
          variant="smooth"
          size="tiny"
          color-scheme="secondary"
          class-names="grey-btn"
          icon="microphone-pause"
          :is-loading="loading"
          @click="emit('pause')"
        />
        <woot-button
          v-tooltip.top="$t('ACCOUNT_FORM.DETAIL.SAVE_TOOLTIP')"
          variant="smooth"
          size="tiny"
          color-scheme="secondary"
          class-names="grey-btn"
          icon="edit"
          :is-loading="loading"
          @click="emit('open')"
        />
        <woot-button
          v-tooltip.top="$t('ACCOUNT_FORM.LIST.DELETE_TOOLTIP')"
          variant="smooth"
          size="tiny"
          color-scheme="alert"
          class-names="grey-btn"
          icon="dismiss-circle"
          :is-loading="loading"
          @click="emit('delete')"
        />
      </div>
    </td>
  </tr>
</template>
