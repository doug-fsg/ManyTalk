<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  workflow: {
    type: Object,
    required: true,
  },
  loading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['toggle', 'edit', 'delete', 'clone']);

const { t } = useI18n();

const activeCount = computed(() => props.workflow.metrics?.active_count ?? 0);

const replyRate = computed(() => props.workflow.metrics?.reply_rate_30d ?? null);

const conflictingAutomations = computed(
  () => props.workflow.conflicting_automations ?? []
);
const hasConflicts = computed(
  () => conflictingAutomations.value.length > 0 && props.workflow.active
);

const metricsTooltip = computed(() => {
  const running = t('WORKFLOW.LIST.METRICS_ACTIVE', {
    count: activeCount.value,
  });
  const rate =
    replyRate.value != null
      ? t('WORKFLOW.LIST.METRICS_REPLY_RATE', { rate: replyRate.value })
      : t('WORKFLOW.LIST.METRICS_REPLY_EMPTY');
  return `${running} · ${rate}\n${t('WORKFLOW.LIST.METRICS_PERIOD')}`;
});

const TRIGGER_LABEL_I18N_KEYS = {
  conversation_created: 'WORKFLOW.LIST.TRIGGER_LABELS.conversation_created',
  conversation_updated: 'WORKFLOW.LIST.TRIGGER_LABELS.conversation_updated',
  conversation_opened: 'WORKFLOW.LIST.TRIGGER_LABELS.conversation_opened',
  conversation_resolved: 'WORKFLOW.LIST.TRIGGER_LABELS.conversation_resolved',
  message_created: 'WORKFLOW.LIST.TRIGGER_LABELS.message_created',
  manual: 'WORKFLOW.LIST.TRIGGER_LABELS.manual',
  contact_kanban_stage_changed:
    'WORKFLOW.LIST.TRIGGER_LABELS.contact_kanban_stage_changed',
  contact_kanban_stage_idle:
    'WORKFLOW.LIST.TRIGGER_LABELS.contact_kanban_stage_idle',
  form_submitted: 'WORKFLOW.LIST.TRIGGER_LABELS.form_submitted',
};

const triggerLabel = computed(() => {
  const eventName = props.workflow.trigger_event_name;
  if (!eventName) return t('WORKFLOW.LIST.TRIGGER_UNKNOWN');
  const key = TRIGGER_LABEL_I18N_KEYS[eventName];
  return key ? t(key) : eventName;
});

const statusLabel = computed(() =>
  props.workflow.active
    ? t('WORKFLOW.LIST.ACTIVE')
    : t('WORKFLOW.LIST.INACTIVE')
);

const reportRoute = computed(() => ({
  name: 'workflow_reports',
  query: { workflowId: String(props.workflow.id) },
}));

const toggle = () => {
  emit('toggle', {
    id: props.workflow.id,
    name: props.workflow.name,
    active: props.workflow.active,
  });
};
</script>

<template>
  <div
    class="flex flex-col p-5 bg-white border border-solid rounded-xl dark:bg-slate-800 border-slate-75 dark:border-slate-700/50 shadow-soft hover:shadow-soft-lg transition-all duration-300 ease-smooth"
  >
    <div class="flex items-start justify-between gap-3 mb-3">
      <div class="min-w-0 flex-1">
        <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100 truncate">
          {{ workflow.name }}
        </h3>
        <p
          v-if="workflow.description"
          class="mt-1 text-sm text-slate-600 dark:text-slate-300 line-clamp-2"
        >
          {{ workflow.description }}
        </p>
      </div>
      <woot-switch :value="workflow.active" @input="toggle" />
    </div>

    <div class="flex flex-wrap items-center gap-2 mb-4">
      <span
        class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md"
        :class="
          workflow.active
            ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300'
            : 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300'
        "
      >
        {{ statusLabel }}
      </span>
      <span
        class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
      >
        {{ triggerLabel }}
      </span>
    </div>

    <div
      v-if="hasConflicts"
      class="flex items-start gap-2 mb-3 rounded-lg border border-amber-200 bg-amber-50 dark:border-amber-800/50 dark:bg-amber-950/30 px-3 py-2"
    >
      <fluent-icon icon="warning" size="14" class="text-amber-500 dark:text-amber-400 shrink-0 mt-0.5" />
      <p class="text-xs text-amber-700 dark:text-amber-300 leading-snug">
        {{ $t('WORKFLOW.LIST.CONFLICT_WARNING', { names: conflictingAutomations.join(', ') }) }}
      </p>
    </div>

    <div
      v-tooltip.top="{
        content: metricsTooltip,
        delay: { show: 200, hide: 0 },
      }"
      class="flex items-center gap-3 mb-4 tabular-nums cursor-default"
    >
      <span class="inline-flex items-center gap-1 text-sm text-slate-700 dark:text-slate-300">
        <fluent-icon icon="play-circle" size="14" class="text-slate-400 dark:text-slate-500" aria-hidden="true" />
        <span class="font-medium">{{ activeCount }}</span>
        <span class="text-xs text-slate-400 dark:text-slate-500">{{ $t('WORKFLOW.LIST.METRICS_LABEL_RUNNING') }}</span>
      </span>
      <span class="text-slate-200 dark:text-slate-700" aria-hidden="true">·</span>
      <span class="inline-flex items-center gap-1 text-sm text-slate-700 dark:text-slate-300">
        <fluent-icon icon="arrow-reply" size="14" class="text-slate-400 dark:text-slate-500" aria-hidden="true" />
        <span class="font-medium">{{ replyRate != null ? replyRate + '%' : '—' }}</span>
        <span class="text-xs text-slate-400 dark:text-slate-500">{{ $t('WORKFLOW.LIST.METRICS_LABEL_RATE') }}</span>
      </span>
    </div>

    <div class="flex items-center gap-1 mt-auto pt-3 border-t border-slate-50 dark:border-slate-700/50">
      <router-link :to="reportRoute">
        <woot-button
          v-tooltip.top="$t('WORKFLOW.LIST.GOTO_REPORT')"
          variant="smooth"
          size="tiny"
          color-scheme="secondary"
          class-names="grey-btn"
          icon="arrow-right"
        />
      </router-link>
      <woot-button
        v-tooltip.top="$t('WORKFLOW.LIST.EDIT')"
        variant="smooth"
        size="tiny"
        color-scheme="secondary"
        class-names="grey-btn"
        icon="edit"
        :is-loading="loading"
        @click="$emit('edit', workflow)"
      />
      <woot-button
        v-tooltip.top="$t('WORKFLOW.LIST.CLONE')"
        variant="smooth"
        size="tiny"
        color-scheme="primary"
        class-names="grey-btn"
        icon="copy"
        :is-loading="loading"
        @click="$emit('clone', workflow)"
      />
      <woot-button
        v-tooltip.top="$t('WORKFLOW.LIST.DELETE')"
        variant="smooth"
        color-scheme="alert"
        size="tiny"
        icon="dismiss-circle"
        class-names="grey-btn"
        :is-loading="loading"
        @click="$emit('delete', workflow)"
      />
    </div>
  </div>
</template>
