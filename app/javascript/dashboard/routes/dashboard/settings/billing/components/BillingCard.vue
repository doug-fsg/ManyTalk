<script setup>
import BillingHeader from './BillingHeader.vue';

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
  <div
    class="rounded-xl shadow-sm border border-slate-75 dark:border-slate-700 bg-white dark:bg-slate-800 py-5 space-y-5"
  >
    <BillingHeader :title="title" :description="description" class="px-5">
      <slot name="action" />
    </BillingHeader>
    <slot />
  </div>
</template>
