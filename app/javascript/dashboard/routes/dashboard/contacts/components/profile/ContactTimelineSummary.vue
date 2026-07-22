<script setup>
defineProps({
  summary: {
    type: Object,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div
    class="mb-4 grid gap-2"
    :class="compact ? 'grid-cols-1 sm:grid-cols-2' : 'grid-cols-1 sm:grid-cols-2 xl:grid-cols-4'"
  >
    <div
      class="rounded-lg border border-slate-100 bg-white px-3 py-2.5 dark:border-slate-700 dark:bg-slate-900"
    >
      <p class="text-[11px] font-medium uppercase tracking-wide text-slate-400 dark:text-slate-500">
        {{ $t('CONTACT_PROFILE.TIMELINE.SUMMARY.ORIGIN_LABEL') }}
      </p>
      <p class="mt-1 text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ summary.firstContactLabel }}
      </p>
    </div>

    <div
      v-if="summary.pipelineLabel"
      class="rounded-lg border border-slate-100 bg-white px-3 py-2.5 dark:border-slate-700 dark:bg-slate-900"
    >
      <p class="text-[11px] font-medium uppercase tracking-wide text-slate-400 dark:text-slate-500">
        {{ $t('CONTACT_PROFILE.TIMELINE.SUMMARY.PIPELINE_LABEL') }}
      </p>
      <p class="mt-1 text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ summary.pipelineLabel }}
      </p>
    </div>

    <div
      class="rounded-lg border border-slate-100 bg-white px-3 py-2.5 dark:border-slate-700 dark:bg-slate-900"
    >
      <p class="text-[11px] font-medium uppercase tracking-wide text-slate-400 dark:text-slate-500">
        {{ $t('CONTACT_PROFILE.TIMELINE.SUMMARY.LAST_INTERACTION_LABEL') }}
      </p>
      <p class="mt-1 text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ summary.lastInteractionLabel }}
      </p>
    </div>

    <div
      v-if="summary.nextActivityLabel"
      class="rounded-lg border border-slate-100 bg-white px-3 py-2.5 dark:border-slate-700 dark:bg-slate-900"
    >
      <p class="text-[11px] font-medium uppercase tracking-wide text-slate-400 dark:text-slate-500">
        {{ $t('CONTACT_PROFILE.TIMELINE.SUMMARY.NEXT_ACTIVITY_LABEL') }}
      </p>
      <p class="mt-1 text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ summary.nextActivityLabel }}
      </p>
    </div>
  </div>
</template>
