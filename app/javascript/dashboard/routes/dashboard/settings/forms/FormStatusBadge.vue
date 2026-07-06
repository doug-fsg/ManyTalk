<script setup>
import { computed } from 'vue';

const props = defineProps({
  status: {
    type: String,
    required: true,
    validator: value => ['draft', 'published', 'paused'].includes(value),
  },
  pill: {
    type: Boolean,
    default: false,
  },
});

const statusClass = computed(() => {
  switch (props.status) {
    case 'published':
      return 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400';
    case 'paused':
      return 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400';
    default:
      return 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300';
  }
});

const shapeClass = computed(() =>
  props.pill ? 'rounded-full' : 'rounded-md'
);
</script>

<template>
  <span
    class="inline-flex items-center px-2 py-0.5 text-xs font-medium"
    :class="[statusClass, shapeClass]"
  >
    {{ $t(`ACCOUNT_FORM.STATUS.${status.toUpperCase()}`) }}
  </span>
</template>
