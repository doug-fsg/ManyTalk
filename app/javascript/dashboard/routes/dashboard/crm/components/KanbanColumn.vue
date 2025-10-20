<template>
  <div 
    class="kanban-column"
    :data-id="column.id"
    :data-title="column.title"
    :style="{ backgroundColor: getLightColor(column.color) }"
  >
    <div 
      class="p-3 font-medium cursor-move relative border-b border-slate-800"
      :data-title="column.title"
      :style="{ backgroundColor: getHeaderColor(column.color) }"
    >
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-2">
          <span class="text-base text-white font-semibold">{{ column.title }}</span>
          <span class="text-xs bg-white/10 text-slate-200 rounded-full px-2 py-0.5 font-medium">{{ column.items.length }}</span>
        </div>
        <div class="flex items-center gap-2">
          <div v-if="columnTotal > 0" class="text-xs text-slate-300 font-normal opacity-95">
            {{ formatCurrency(columnTotal) }}
          </div>
          <woot-button
            icon="add"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            class="opacity-70 hover:opacity-100 transition-opacity"
            @click="addContactToStage"
            v-tooltip.top="$t('KANBAN.ADD_CONTACT_TO_STAGE', { stage: column.title })"
          >
          </woot-button>
        </div>
      </div>
    </div>
    <div class="column-content">
      <draggable
        v-model="columnItems"
        class="column-items"
        :data-column-id="column.id"
        :data-column-title="column.title"
        group="items"
        animation="150"
        ghost-class="ghost-card"
        @end="onItemMoved"
      >
        <kanban-card
          v-for="contact in columnItems"
          :key="contact.id"
          :contact="contact"
          :pipeline-id="pipelineId"
          :is-updating="isCardUpdating(contact.id)"
          :has-error="hasCardError(contact.id)"
          @view="$emit('view-contact', contact.id)"
          @remove="$emit('remove-card', contact.id)"
          @open-conversation="$emit('open-conversation', $event)"
          @value-updated="handleValueUpdated"
          @win-lost-updated="handleWinLostUpdated"
          @open-win-modal="$emit('open-win-modal', $event)"
          @open-lost-modal="$emit('open-lost-modal', $event)"
          @undo-win-lost="$emit('undo-win-lost', $event)"
        />
        <div v-if="!columnItems.length" class="flex items-center justify-center h-[100px] text-slate-400 text-sm text-center p-4 bg-black/5 rounded-md border border-dashed border-slate-700">
          <p class="m-0">{{ $t('KANBAN.NO_CONTACTS') }}</p>
        </div>
      </draggable>
    </div>
  </div>
</template>

<script>
import draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';

export default {
  name: 'KanbanColumn',
  components: {
    draggable,
    KanbanCard,
  },
  props: {
    column: {
      type: Object,
      required: true,
    },
    operationManager: {
      type: Object,
      default: null,
    },
    pipelineId: {
      type: [Number, String],
      required: true
    }
  },
  computed: {
    columnItems: {
      get() {
        return this.column.items;
      },
      set(value) {
        this.$emit('update:items', {
          columnId: this.column.id,
          items: value
        });
      }
    },
    columnTotal() {
      return this.columnItems.reduce((total, contact) => {
        const additionalAttributes = contact.additional_attributes || {};
        const kanban = additionalAttributes.kanban || {};
        const pipelineData = kanban[this.pipelineId] || {};
        const deal = pipelineData.deal || {};
        const value = deal.value || 0;
        return total + parseFloat(value);
      }, 0);
    }
  },
  methods: {
    getLightColor(hexColor) {
      // Função para criar uma versão mais clara da cor
      if (!hexColor) return 'rgba(245, 245, 250, 0.3)'; // Cor padrão clara
      
      // Converter hex para RGB e adicionar transparência
      let hex = hexColor.replace('#', '');
      if (hex.length === 3) {
        hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
      }
      
      const r = parseInt(hex.substring(0, 2), 16);
      const g = parseInt(hex.substring(2, 4), 16);
      const b = parseInt(hex.substring(4, 6), 16);
      
      // Retorna uma versão clara com baixa opacidade
      return `rgba(${r}, ${g}, ${b}, 0.08)`;
    },
    getHeaderColor(hexColor) {
      // Função para criar uma versão mais forte da cor para o cabeçalho
      if (!hexColor) return 'rgba(245, 245, 250, 0.5)'; // Cor padrão para o cabeçalho
      
      // Converter hex para RGB e adicionar transparência
      let hex = hexColor.replace('#', '');
      if (hex.length === 3) {
        hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
      }
      
      const r = parseInt(hex.substring(0, 2), 16);
      const g = parseInt(hex.substring(2, 4), 16);
      const b = parseInt(hex.substring(4, 6), 16);
      
      // Retorna uma versão mais forte com opacidade maior
      return `rgba(${r}, ${g}, ${b}, 0.15)`;
    },
    onItemMoved(event) {
      if (!event || !event.item) return;
      
      const contactId = parseInt(event.item.getAttribute('data-contact-id'), 10);
      const sourceColumnId = event.from.getAttribute('data-column-id');
      const targetColumnId = event.to.getAttribute('data-column-id');
      const sourceTitle = event.from.getAttribute('data-column-title');
      const targetTitle = event.to.getAttribute('data-column-title');
      
      // Emitir evento para o componente pai processar
      this.$emit('item-moved', {
        contactId,
        sourceColumnId,
        targetColumnId,
        sourceColumnTitle: sourceTitle,
        targetColumnTitle: targetTitle,
        timestamp: Date.now()
      });
    },
    isCardUpdating(contactId) {
      return this.operationManager && this.operationManager.isOperationPending(contactId);
    },
    hasCardError(contactId) {
      return this.operationManager && this.operationManager.hasOperationFailed(contactId);
    },
    handleValueUpdated(data) {
      this.$emit('value-updated', {
        ...data,
        columnId: this.column.id
      });
    },
    handleWinLostUpdated(data) {
      this.$emit('win-lost-updated', {
        ...data,
        columnId: this.column.id
      });
    },
    addContactToStage() {
      this.$emit('add-contact-to-stage', {
        stage: this.column.title,
        pipelineId: this.pipelineId
      });
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL'
      }).format(value);
    }
  }
};
</script>

<style lang="scss" scoped>
.kanban-column {
  flex: 0 0 320px;
  display: flex;
  flex-direction: column;
  border-radius: var(--border-radius-large);
  box-shadow: var(--shadow-small);
  border: 1px solid var(--s-100);
  overflow: hidden;
  transition: box-shadow 0.2s ease;
  
  &:hover {
    box-shadow: var(--shadow-medium);
  }
  
  .dark-mode & {
    border-color: var(--b-600);
  }
}

.column-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-small);
  
  &::-webkit-scrollbar {
    width: 4px;
  }
  
  &::-webkit-scrollbar-thumb {
    background-color: var(--s-200);
    border-radius: 2px;
    
    .dark-mode & {
      background-color: var(--b-500);
    }
  }
}

.column-items {
  min-height: 100px;
  display: flex;
  flex-direction: column;
  gap: var(--space-small);
}

.ghost-card {
  opacity: 0.5;
}
</style> 