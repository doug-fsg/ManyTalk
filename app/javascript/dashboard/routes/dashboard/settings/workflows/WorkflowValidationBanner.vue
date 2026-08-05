<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { humanizeValidationError } from 'dashboard/helper/workflowValidationMessages';

const props = defineProps({
  errors: { type: Array, default: () => [] },
});

const emit = defineEmits(['dismiss', 'focus-error']);

const { t } = useI18n();
const activeIndex = ref(0);

const items = computed(() =>
  (props.errors || []).map((err, index) => ({
    index,
    nodeId: err?.node_id || null,
    message: humanizeValidationError(err?.message, t),
  }))
);

const errorCount = computed(() => items.value.length);

const title = computed(() => {
  if (errorCount.value === 1) return t('WORKFLOW.EDITOR.VALIDATION_TITLE_ONE');
  return t('WORKFLOW.EDITOR.VALIDATION_TITLE', { count: errorCount.value });
});

const positionLabel = computed(() =>
  t('WORKFLOW.EDITOR.VALIDATION_POSITION', {
    current: activeIndex.value + 1,
    total: errorCount.value || 1,
  })
);

watch(
  () => props.errors,
  () => {
    activeIndex.value = 0;
  }
);

watch(errorCount, count => {
  if (activeIndex.value >= count) {
    activeIndex.value = Math.max(0, count - 1);
  }
});

const focusItem = index => {
  if (index < 0 || index >= items.value.length) return;
  activeIndex.value = index;
  const item = items.value[index];
  if (item?.nodeId) emit('focus-error', item.nodeId);
};

const goPrev = () => {
  if (!items.value.length) return;
  const next =
    (activeIndex.value - 1 + items.value.length) % items.value.length;
  focusItem(next);
};

const goNext = () => {
  if (!items.value.length) return;
  const next = (activeIndex.value + 1) % items.value.length;
  focusItem(next);
};
</script>

<template>
  <div
    class="flex-shrink-0 border-b border-amber-200/70 dark:border-amber-800/40 bg-amber-50/70 dark:bg-amber-950/25 text-amber-900/90 dark:text-amber-200/90"
    role="alert"
    aria-live="polite"
  >
    <div class="flex items-center justify-between gap-3 px-4 py-1.5 text-xs">
      <span class="flex items-center gap-1.5 min-w-0">
        <fluent-icon
          icon="warning"
          size="14"
          class="text-amber-600 dark:text-amber-400 flex-shrink-0"
          aria-hidden="true"
        />
        <span class="truncate font-medium">{{ title }}</span>
      </span>

      <div class="flex items-center gap-1.5 shrink-0">
        <template v-if="errorCount > 1">
          <span
            class="tabular-nums text-amber-800/70 dark:text-amber-300/70 hidden sm:inline"
            translate="no"
          >
            {{ positionLabel }}
          </span>
          <button
            type="button"
            class="inline-flex items-center justify-center w-7 h-7 rounded-lg text-amber-800/80 dark:text-amber-300/80 hover:bg-amber-100/80 dark:hover:bg-amber-900/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-500 cursor-pointer transition-colors duration-200"
            :aria-label="$t('WORKFLOW.EDITOR.VALIDATION_PREV')"
            @click="goPrev"
          >
            <fluent-icon icon="chevron-left" size="14" aria-hidden="true" />
          </button>
          <button
            type="button"
            class="inline-flex items-center justify-center w-7 h-7 rounded-lg text-amber-800/80 dark:text-amber-300/80 hover:bg-amber-100/80 dark:hover:bg-amber-900/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-500 cursor-pointer transition-colors duration-200"
            :aria-label="$t('WORKFLOW.EDITOR.VALIDATION_NEXT')"
            @click="goNext"
          >
            <fluent-icon icon="chevron-right" size="14" aria-hidden="true" />
          </button>
        </template>
        <button
          type="button"
          class="inline-flex items-center justify-center w-7 h-7 rounded-lg text-amber-800/70 dark:text-amber-300/70 hover:text-amber-900 dark:hover:text-amber-100 hover:bg-amber-100/80 dark:hover:bg-amber-900/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-500 cursor-pointer transition-colors duration-200"
          :aria-label="$t('WORKFLOW.EDITOR.VALIDATION_DISMISS')"
          @click="emit('dismiss')"
        >
          <fluent-icon icon="dismiss" size="14" aria-hidden="true" />
        </button>
      </div>
    </div>

    <ul
      class="list-none m-0 px-4 pb-2 space-y-1 max-h-28 overflow-y-auto overscroll-contain"
      :aria-label="title"
    >
      <li v-for="item in items" :key="`${item.index}-${item.nodeId || 'global'}`">
        <button
          type="button"
          class="flex w-full items-start gap-2 rounded-lg px-2 py-1.5 text-left text-xs cursor-pointer transition-colors duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-500"
          :class="
            item.index === activeIndex
              ? 'bg-amber-100/90 dark:bg-amber-900/40 text-amber-950 dark:text-amber-100'
              : 'hover:bg-amber-100/60 dark:hover:bg-amber-900/25 text-amber-900/90 dark:text-amber-200/90'
          "
          :disabled="!item.nodeId"
          :aria-current="item.index === activeIndex ? 'true' : undefined"
          @click="focusItem(item.index)"
        >
          <fluent-icon
            :icon="item.nodeId ? 'arrow-right' : 'info'"
            size="12"
            class="flex-shrink-0 mt-0.5 opacity-70"
            aria-hidden="true"
          />
          <span class="min-w-0 break-words">{{ item.message }}</span>
          <span
            v-if="item.nodeId"
            class="ml-auto shrink-0 text-[10px] font-medium uppercase tracking-wide opacity-70"
          >
            {{ $t('WORKFLOW.EDITOR.VALIDATION_GO_TO_NODE') }}
          </span>
        </button>
      </li>
    </ul>
  </div>
</template>
