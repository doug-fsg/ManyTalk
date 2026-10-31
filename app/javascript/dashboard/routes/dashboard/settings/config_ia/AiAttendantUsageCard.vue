<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  usage: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const formatUsageNumber = value =>
  value === null || value === undefined ? '—' : value;

const hasLimit = computed(
  () =>
    props.usage.limit !== null && props.usage.limit !== undefined
);

const usagePercent = computed(() => {
  if (!hasLimit.value) return null;
  const limit = Number(props.usage.limit);
  if (!limit || limit <= 0) return null;
  const used = Number(props.usage.used) || 0;
  return Math.min(100, Math.round((used / limit) * 100));
});

const progressBarClass = computed(() => {
  const pct = usagePercent.value;
  if (pct === null) return 'bg-woot-500';
  if (pct >= 90) return 'bg-red-500';
  if (pct >= 70) return 'bg-yellow-500';
  return 'bg-woot-500';
});
</script>

<template>
  <div
    class="w-full p-4 mb-4 rounded-xl border border-slate-100 dark:border-slate-700/50 bg-gradient-to-br from-slate-25 to-white dark:from-slate-800/80 dark:to-slate-900"
  >
    <div class="flex flex-wrap items-start justify-between gap-3 mb-4">
      <div>
        <h2
          class="mb-0.5 text-base font-semibold text-slate-900 dark:text-slate-25"
        >
          {{ $t('AI_ATTENDANT.USAGE.TITLE') }}
        </h2>
        <p class="text-xs text-slate-500 dark:text-slate-400 m-0">
          {{ $t('AI_ATTENDANT.USAGE.SUBTITLE') }}
        </p>
      </div>
      <span
        v-if="usage.paused"
        class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-medium bg-yellow-100 text-yellow-900 dark:bg-yellow-900/40 dark:text-yellow-200"
      >
        <fluent-icon icon="warning" size="14" />
        {{ $t('AI_ATTENDANT.USAGE.PAUSED') }}
      </span>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-4">
      <div
        class="rounded-lg border border-slate-100 dark:border-slate-700/50 bg-white/80 dark:bg-slate-900/60 px-3 py-2.5"
      >
        <p class="text-[0.65rem] uppercase tracking-wide text-slate-500 dark:text-slate-400 m-0 mb-1">
          {{ $t('AI_ATTENDANT.USAGE.STAT_LIMIT') }}
        </p>
        <p class="text-lg font-semibold text-slate-900 dark:text-slate-100 m-0">
          {{
            hasLimit
              ? formatUsageNumber(usage.limit)
              : $t('AI_ATTENDANT.USAGE.UNLIMITED')
          }}
        </p>
      </div>
      <div
        class="rounded-lg border border-slate-100 dark:border-slate-700/50 bg-white/80 dark:bg-slate-900/60 px-3 py-2.5"
      >
        <p class="text-[0.65rem] uppercase tracking-wide text-slate-500 dark:text-slate-400 m-0 mb-1">
          {{ $t('AI_ATTENDANT.USAGE.STAT_USED') }}
        </p>
        <p class="text-lg font-semibold text-slate-900 dark:text-slate-100 m-0">
          {{ formatUsageNumber(usage.used) }}
        </p>
      </div>
      <div
        class="rounded-lg border border-slate-100 dark:border-slate-700/50 bg-white/80 dark:bg-slate-900/60 px-3 py-2.5"
      >
        <p class="text-[0.65rem] uppercase tracking-wide text-slate-500 dark:text-slate-400 m-0 mb-1">
          {{ $t('AI_ATTENDANT.USAGE.STAT_REMAINING') }}
        </p>
        <p class="text-lg font-semibold text-slate-900 dark:text-slate-100 m-0">
          {{
            hasLimit
              ? formatUsageNumber(usage.remaining)
              : '—'
          }}
        </p>
      </div>
    </div>

    <p
      v-if="usage.paused"
      class="text-sm text-yellow-800 dark:text-yellow-200 m-0 mb-4 leading-5"
    >
      {{ $t('AI_ATTENDANT.USAGE.PAUSED_HELP') }}
    </p>

    <div v-if="usagePercent !== null" class="space-y-1.5">
      <div
        class="flex justify-between text-xs text-slate-600 dark:text-slate-400"
      >
        <span>{{ $t('AI_ATTENDANT.USAGE.PROGRESS_LABEL') }}</span>
        <span>{{ usagePercent }}%</span>
      </div>
      <div
        class="h-2 w-full rounded-full bg-slate-100 dark:bg-slate-700 overflow-hidden"
        role="progressbar"
        :aria-valuenow="usagePercent"
        aria-valuemin="0"
        aria-valuemax="100"
      >
        <div
          class="h-full rounded-full transition-all duration-300"
          :class="progressBarClass"
          :style="{ width: `${usagePercent}%` }"
        />
      </div>
    </div>
  </div>
</template>
