<template>
  <div class="space-y-2">
    <label :for="selectId" class="input-label w-full">
      {{ $t('WORKFLOW.REGUA.REBIND_LABEL') }}
      <select
        :id="selectId"
        :value="modelValue"
        name="rebind_conversation_id"
        class="w-full mb-0 bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-100 border-slate-75 dark:border-slate-600"
        @change="$emit('update:modelValue', Number($event.target.value))"
      >
        <option
          v-for="conv in conversations"
          :key="conv.id"
          :value="conv.id"
        >
          {{ conv.label }}
        </option>
      </select>
    </label>
    <div class="flex flex-row justify-end">
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        :disabled="modelValue === currentConversationId"
        :is-loading="isRebinding"
        @click="$emit('rebind', modelValue)"
      >
        {{ $t('WORKFLOW.REGUA.REBIND_CONFIRM') }}
      </woot-button>
    </div>
  </div>
</template>

<script setup>
const selectId = `fluxo-rebind-select-${Math.random().toString(36).slice(2, 8)}`;

defineProps({
  conversations: { type: Array, default: () => [] },
  currentConversationId: { type: Number, required: true },
  modelValue: { type: Number, default: null },
  isRebinding: { type: Boolean, default: false },
});

defineEmits(['update:modelValue', 'rebind']);
</script>
