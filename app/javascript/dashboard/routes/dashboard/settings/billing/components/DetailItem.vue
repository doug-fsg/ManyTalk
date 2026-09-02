<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  value: {
    type: [String, Number],
    required: true,
  },
  variant: {
    type: String,
    default: 'default',
  },
});
</script>

<template>
  <div class="px-5">
    <span class="text-slate-600 dark:text-slate-400 text-xs">
      {{ label }}
    </span>
    <div
      class="mt-2 text-xl font-medium"
      :class="
        variant === 'warning'
          ? 'text-amber-700 dark:text-amber-300'
          : 'text-slate-900 dark:text-slate-25'
      "
    >
      {{ value }}
    </div>
  </div>
</template>
