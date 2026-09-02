<script setup>
defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <div class="grid grid-cols-[1fr_auto] gap-5 items-start">
    <div>
      <span class="text-base font-medium text-slate-900 dark:text-slate-25">
        {{ title }}
      </span>
      <p class="text-sm mt-1 text-slate-600 dark:text-slate-300">
        {{ description }}
      </p>
    </div>
    <slot />
  </div>
</template>
