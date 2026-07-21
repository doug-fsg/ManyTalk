<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useRouter } from 'dashboard/composables/route';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import { dynamicTime } from 'shared/helpers/timeHelper';

const props = defineProps({
  contact: {
    type: Object,
    required: true,
  },
  accountId: {
    type: [String, Number],
    required: true,
  },
  primaryPipelineName: {
    type: String,
    default: null,
  },
  primaryStage: {
    type: String,
    default: null,
  },
  stageColor: {
    type: String,
    default: '#6B7280',
  },
  primaryDealValue: {
    type: Number,
    default: null,
  },
  primaryAssignee: {
    type: Object,
    default: null,
  },
  primaryWinLost: {
    type: Object,
    default: null,
  },
  enteredAt: {
    type: String,
    default: null,
  },
  hasPipeline: {
    type: Boolean,
    default: false,
  },
  kanbanDeepLink: {
    type: Object,
    default: null,
  },
  resolvedPipelineId: {
    type: [String, Number],
    default: null,
  },
});

const { t } = useI18n();
const router = useRouter();

const stageBadgeStyle = computed(() => ({
  backgroundColor: `${props.stageColor}20`,
  color: props.stageColor,
}));

const formattedDealValue = computed(() => {
  if (props.primaryDealValue == null) return '—';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(props.primaryDealValue);
});

const timeInStage = computed(() => {
  if (!props.enteredAt) return null;
  return dynamicTime(new Date(props.enteredAt).getTime() / 1000);
});

const winLostLabel = computed(() => {
  if (!props.primaryWinLost?.status) return null;
  return props.primaryWinLost.status === 'won'
    ? t('CONTACT_PROFILE.DEAL.WON')
    : t('CONTACT_PROFILE.DEAL.LOST');
});

const winLostClass = computed(() =>
  props.primaryWinLost?.status === 'won'
    ? 'text-green-700 dark:text-green-400'
    : 'text-red-700 dark:text-red-400'
);

const assigneeName = computed(() => {
  if (props.primaryAssignee && props.primaryAssignee.name) {
    return props.primaryAssignee.name;
  }
  return t('CONTACT_PROFILE.DEAL.NO_ASSIGNEE');
});

const winLostIcon = computed(() =>
  props.primaryWinLost && props.primaryWinLost.status === 'won'
    ? 'checkmark-circle'
    : 'dismiss-circle'
);

const winLostNotes = computed(() =>
  props.primaryWinLost && props.primaryWinLost.notes
    ? props.primaryWinLost.notes
    : ''
);

const showWinLostNotes = computed(() => Boolean(winLostNotes.value));

const openKanban = () => {
  if (!props.kanbanDeepLink) return;
  router.push(props.kanbanDeepLink);
};
</script>

<template>
  <div class="space-y-4">
    <div
      v-if="!hasPipeline"
      class="rounded-xl border border-dashed border-slate-300 px-4 py-8 text-center dark:border-slate-600"
    >
      <p class="text-sm font-medium text-slate-700 dark:text-slate-200">
        {{ $t('CONTACT_PROFILE.DEAL.NO_PIPELINE_TITLE') }}
      </p>
      <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CONTACT_PROFILE.DEAL.NO_PIPELINE_HINT') }}
      </p>
    </div>

    <template v-else>
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p
            class="text-xs uppercase tracking-wide text-slate-500 dark:text-slate-400"
          >
            {{ primaryPipelineName }}
          </p>
          <div class="mt-2 flex flex-wrap items-center gap-2">
            <span
              class="inline-flex rounded-full px-3 py-1 text-sm font-semibold"
              :style="stageBadgeStyle"
            >
              {{ primaryStage }}
            </span>
            <span
              v-if="winLostLabel"
              class="inline-flex items-center gap-1 text-sm font-medium"
              :class="winLostClass"
            >
              <FluentIcon :icon="winLostIcon" size="14" />
              {{ winLostLabel }}
            </span>
          </div>
        </div>

        <woot-button
          icon="board"
          size="small"
          variant="smooth"
          color-scheme="primary"
          @click="openKanban"
        >
          {{ $t('CONTACT_PROFILE.HEADER.OPEN_IN_PIPELINE') }}
        </woot-button>
      </div>

      <div class="grid gap-3 md:grid-cols-3">
        <div
          class="rounded-xl border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
        >
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('CONTACT_PROFILE.DEAL.VALUE') }}
          </p>
          <p class="mt-1 text-lg font-semibold text-slate-900 dark:text-white">
            {{ formattedDealValue }}
          </p>
        </div>

        <div
          class="rounded-xl border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
        >
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('CONTACT_PROFILE.DEAL.ASSIGNEE') }}
          </p>
          <p class="mt-1 text-sm font-medium text-slate-900 dark:text-white">
            {{ assigneeName }}
          </p>
        </div>

        <div
          class="rounded-xl border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
        >
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('KANBAN.LIST_VIEW.TIME_IN_STAGE') }}
          </p>
          <p class="mt-1 text-sm font-medium text-slate-900 dark:text-white">
            {{ timeInStage || '—' }}
          </p>
        </div>
      </div>

      <div
        v-if="showWinLostNotes"
        class="rounded-xl border border-slate-200 bg-slate-50 p-4 dark:border-slate-700 dark:bg-slate-800/60"
      >
        <p class="text-xs font-medium text-slate-500 dark:text-slate-400">
          {{ $t('CONTACT_PROFILE.DEAL.WIN_LOST_NOTES') }}
        </p>
        <p class="mt-1 text-sm text-slate-700 dark:text-slate-200">
          {{ winLostNotes }}
        </p>
      </div>
    </template>
  </div>
</template>
