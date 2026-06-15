<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  errorCount: { type: Number, default: 0 },
});

const emit = defineEmits(['dismiss']);

const { t } = useI18n();

const title = computed(() => {
  const count = props.errorCount;
  if (count === 1) return t('WORKFLOW.EDITOR.VALIDATION_TITLE_ONE');
  return t('WORKFLOW.EDITOR.VALIDATION_TITLE', { count });
});
</script>

<template>
  <div
    class="flex-shrink-0 flex items-center justify-between gap-3 px-4 py-1.5 text-xs border-b border-amber-200/70 dark:border-amber-800/40 bg-amber-50/70 dark:bg-amber-950/25 text-amber-900/90 dark:text-amber-200/90"
    role="status"
    aria-live="polite"
  >
    <span class="flex items-center gap-1.5 min-w-0">
      <fluent-icon
        icon="warning"
        size="14"
        class="text-amber-600 dark:text-amber-400 flex-shrink-0"
        aria-hidden="true"
      />
      <span class="truncate">{{ title }}</span>
    </span>
    <button
      type="button"
      class="flex-shrink-0 text-amber-800/70 dark:text-amber-300/70 hover:text-amber-900 dark:hover:text-amber-100 cursor-pointer"
      :aria-label="$t('WORKFLOW.EDITOR.VALIDATION_DISMISS')"
      @click="emit('dismiss')"
    >
      <fluent-icon icon="dismiss" size="14" />
    </button>
  </div>
</template>
