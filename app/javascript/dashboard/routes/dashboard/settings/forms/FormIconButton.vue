<script setup>
defineProps({
  icon: { type: String, required: true },
  tooltip: { type: String, default: '' },
  colorScheme: { type: String, default: 'secondary' },
  isLoading: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
});

defineEmits(['click']);
</script>

<template>
  <woot-button
    v-tooltip.top="{ content: tooltip, delay: { show: 200, hide: 0 } }"
    variant="smooth"
    size="tiny"
    :color-scheme="colorScheme"
    class-names="grey-btn"
    :icon="icon"
    :is-loading="isLoading"
    :disabled="disabled"
    :aria-label="tooltip"
    @click="$emit('click')"
  />
</template>
