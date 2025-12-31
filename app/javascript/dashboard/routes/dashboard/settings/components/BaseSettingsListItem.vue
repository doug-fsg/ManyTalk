<script setup>
defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  iconName: {
    type: String,
    default: '',
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

defineEmits(['click']);
</script>

<template>
  <div
    class="flex items-center justify-between p-4 border border-slate-75 dark:border-slate-700 rounded-xl cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800 transition-all duration-200 ease-smooth shadow-soft hover:shadow-soft-lg"
    :class="{ 'opacity-50 cursor-not-allowed': disabled }"
    @click="!disabled && $emit('click')"
  >
    <div class="flex items-center gap-3">
      <div
        v-if="iconName"
        class="flex items-center justify-center w-8 h-8 rounded-full bg-woot-25 dark:bg-woot-900"
      >
        <fluent-icon
          :icon="iconName"
          size="16"
          class="text-woot-500 dark:text-woot-500"
        />
      </div>
      <div>
        <h3 class="text-sm font-medium text-slate-900 dark:text-slate-25">
          {{ title }}
        </h3>
        <p
          v-if="description"
          class="text-xs text-slate-600 dark:text-slate-300 mt-1"
        >
          {{ description }}
        </p>
      </div>
    </div>
    <div class="flex items-center gap-2">
      <slot name="actions" />
      <fluent-icon
        icon="chevron-right"
        size="16"
        class="text-slate-400 dark:text-slate-500"
      />
    </div>
  </div>
</template>