<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header header-title="Preview do Anúncio" header-content="Visualize como ficará o anúncio" />
    <div v-if="announcement" class="p-8">
      <div class="bg-white dark:bg-slate-800 rounded-lg shadow-xl overflow-hidden border border-slate-200 dark:border-slate-700">
        <div v-if="announcement.media_url" class="w-full bg-slate-100 dark:bg-slate-900" style="aspect-ratio: 16/9;">
          <img :src="announcement.media_url" :alt="announcement.title.pt_BR" class="w-full h-full object-cover" />
        </div>
        <div class="p-8">
          <h2 class="text-2xl font-bold text-slate-900 dark:text-slate-100 mb-4">{{ announcement.title.pt_BR }}</h2>
          <p class="text-slate-600 dark:text-slate-400 leading-relaxed">{{ announcement.description.pt_BR }}</p>
        </div>
        <div class="px-8 pb-6 flex gap-3 justify-end">
          <button class="px-4 py-2 border border-slate-300 text-sm font-medium rounded-md">Próximo (1)</button>
          <button class="px-4 py-2 text-sm font-medium rounded-md text-white bg-woot-500">Entendi ✓</button>
        </div>
      </div>
      <div class="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
        <h4 class="text-sm font-medium mb-2">ℹ️ Informações</h4>
        <div class="text-sm space-y-1">
          <p><strong>ID:</strong> {{ announcement.id }}</p>
          <p><strong>Status:</strong> {{ announcement.active ? 'Ativo' : 'Inativo' }}</p>
          <p><strong>Público:</strong> {{ announcement.target_roles.join(', ') }}</p>
        </div>
      </div>
      <div class="flex justify-end mt-4">
        <woot-button class="button clear" @click.prevent="onClose">Fechar</woot-button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  props: { announcement: { type: Object, required: true } },
  methods: {
    onClose() {
      this.$emit('close');
    },
  },
};
</script>
