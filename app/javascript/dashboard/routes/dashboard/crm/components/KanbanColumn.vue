<template>
  <div 
    class="kanban-column"
    :data-id="column.id"
    :data-title="column.title"
  >
    <div 
      class="column-header"
      :style="{ borderTopColor: column.color }"
      :data-title="column.title"
    >
      <span class="column-title">{{ column.title }}</span>
      <span class="column-count">{{ column.items.length }}</span>
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
          :is-updating="isCardUpdating(contact.id)"
          :has-error="hasCardError(contact.id)"
          @view="$emit('view-contact', contact.id)"
          @remove="$emit('remove-card', contact.id)"
          @open-conversation="$emit('open-conversation', $event)"
        />
        <div v-if="!columnItems.length" class="empty-column">
          <p>{{ $t('KANBAN.NO_CONTACTS') }}</p>
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
    }
  },
  methods: {
    onItemMoved(event) {
      if (!event || !event.item) {
        console.log('[KanbanDebug] Evento de movimentação inválido', { event });
        return;
      }
      
      console.log('[KanbanDebug] Iniciando movimentação de card', {
        event,
        item: event.item,
        from: event.from,
        to: event.to
      });
      
      const contactId = parseInt(event.item.dataset.contactId, 10);
      const sourceColumnId = event.from.dataset.columnId;
      const targetColumnId = event.to.dataset.columnId;
      
      console.log('[KanbanDebug] Dados extraídos do evento', {
        contactId,
        sourceColumnId,
        targetColumnId,
        sourceTitle: event.from.dataset.columnTitle,
        targetTitle: event.to.dataset.columnTitle
      });
      
      // Emitir evento para o componente pai processar
      this.$emit('item-moved', {
        contactId,
        sourceColumnId,
        targetColumnId,
        sourceColumnTitle: event.from.dataset.columnTitle,
        targetColumnTitle: event.to.dataset.columnTitle,
        timestamp: Date.now()
      });
    },
    isCardUpdating(contactId) {
      return this.operationManager && this.operationManager.isOperationPending(contactId);
    },
    hasCardError(contactId) {
      return this.operationManager && this.operationManager.hasOperationFailed(contactId);
    },
  }
};
</script>

<style lang="scss" scoped>
.kanban-column {
  flex: 0 0 320px;
  display: flex;
  flex-direction: column;
  background-color: var(--white);
  border-radius: var(--border-radius-large);
  box-shadow: var(--shadow-small);
  border: 1px solid var(--s-100);
  overflow: hidden;
  
  .dark-mode & {
    background-color: var(--b-700);
    border-color: var(--b-600);
  }
}

.column-header {
  padding: var(--space-small) var(--space-normal);
  font-weight: var(--font-weight-medium);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: var(--s-25);
  border-top: 4px solid;
  cursor: move;
  position: relative;
  
  .dark-mode & {
    background-color: var(--b-600);
  }
  
  .column-title {
    font-size: var(--font-size-normal);
  }
  
  .column-count {
    font-size: var(--font-size-small);
    background-color: var(--s-100);
    color: var(--s-800);
    border-radius: var(--border-radius-rounded);
    padding: 2px 8px;
    font-weight: var(--font-weight-medium);
    
    .dark-mode & {
      background-color: var(--b-500);
      color: var(--s-200);
    }
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

.empty-column {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100px;
  color: var(--s-500);
  font-size: var(--font-size-small);
  text-align: center;
  padding: var(--space-normal);
  background-color: var(--s-25);
  border-radius: var(--border-radius-normal);
  border: 1px dashed var(--s-200);
  
  .dark-mode & {
    color: var(--s-400);
    background-color: var(--b-600);
    border-color: var(--b-500);
  }
  
  p {
    margin: 0;
  }
}

.ghost-card {
  opacity: 0.5;
}
</style> 