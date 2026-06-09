<template>
  <div class="flex flex-col gap-4">
    <p class="text-sm text-slate-600 dark:text-slate-300">
      {{ $t('WORKFLOW.REGUA.EMPTY') }}
    </p>

    <div v-if="isLoading" class="text-sm text-slate-500 dark:text-slate-400">
      {{ $t('WORKFLOW.REGUA.LOADING') }}
    </div>

    <template v-else>
      <p
        v-if="!workflows.length"
        class="text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('WORKFLOW.REGUA.NO_ACTIVE_WORKFLOWS') }}
      </p>

      <label v-else :for="selectId" class="input-label w-full">
        {{ $t('WORKFLOW.REGUA.WORKFLOW_LABEL') }}
        <select
          :id="selectId"
          v-model="selectedWorkflowId"
          name="workflow_id"
          class="w-full mb-0 bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-100 border-slate-75 dark:border-slate-600"
        >
          <option value="">
            {{ $t('WORKFLOW.REGUA.SELECT_WORKFLOW') }}
          </option>
          <option v-for="wf in workflows" :key="wf.id" :value="wf.id">
            {{ wf.name }}
          </option>
        </select>
      </label>

      <div class="flex flex-row justify-end gap-2 w-full">
        <woot-button
          size="small"
          :disabled="!selectedWorkflowId || !workflows.length"
          :is-loading="isStarting"
          @click="$emit('start', selectedWorkflowId)"
        >
          {{ $t('WORKFLOW.REGUA.START') }}
        </woot-button>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref } from 'vue';

defineProps({
  workflows: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  isStarting: { type: Boolean, default: false },
});

defineEmits(['start']);

const selectId = `fluxo-workflow-select-${Math.random().toString(36).slice(2, 8)}`;
const selectedWorkflowId = ref('');
</script>
