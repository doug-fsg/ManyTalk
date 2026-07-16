<template>
  <div class="flex items-start gap-2.5">
    <fluent-icon :icon="icon" size="14" class="text-slate-400 dark:text-slate-500 flex-shrink-0 mt-0.5" />
    <div class="min-w-0">
      <p class="text-[11px] text-slate-500 dark:text-slate-400">{{ label }}</p>
      <p class="text-sm text-slate-800 dark:text-slate-200 break-words">{{ value }}</p>
    </div>
  </div>
</template>

<script>
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';

export default {
  name: 'ActivityDetailRow',
  components: { FluentIcon },
  props: {
    icon: { type: String, required: true },
    label: { type: String, required: true },
    value: { type: String, required: true },
  },
};
</script>
