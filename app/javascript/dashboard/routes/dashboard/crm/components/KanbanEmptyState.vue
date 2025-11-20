<template>
  <div class="flex items-center justify-center flex-1 px-4 bg-slate-50 dark:bg-slate-800">
    <div class="text-center max-w-md">
      <!-- Ícone -->
      <div class="mb-6 flex justify-center">
        <div class="p-4 rounded-full bg-slate-100 dark:bg-slate-800">
          <fluent-icon 
            icon="kanban" 
            size="64" 
            class="text-slate-400 dark:text-slate-500"
          />
        </div>
      </div>

      <!-- Título -->
      <h2 class="text-2xl font-semibold text-slate-900 dark:text-white mb-2">
        {{ $t('KANBAN.NO_KANBAN_ATTRIBUTES') }}
      </h2>

      <!-- Descrição -->
      <p class="text-slate-600 dark:text-slate-400 mb-8">
        {{ $t('KANBAN.CREATE_KANBAN_ATTRIBUTE_DESCRIPTION') }}
      </p>

      <!-- Botão -->
      <button
        class="inline-flex items-center gap-2 px-6 py-3 bg-green-500 hover:bg-green-600 dark:bg-green-600 dark:hover:bg-green-700 text-white font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 dark:focus:ring-offset-slate-800"
        @click="$emit('create-pipeline')"
      >
        <fluent-icon icon="add" size="20" />
        <span>{{ $t('KANBAN.CREATE_NEW_ATTRIBUTE') }}</span>
      </button>
    </div>
  </div>
</template>

<script>
export default {
  name: 'KanbanEmptyState',
  emits: ['create-pipeline'],
};
</script>

