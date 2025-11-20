<template>
  <div 
    class="kanban-column"
    :data-id="column.id"
    :data-title="column.title"
    :style="{ backgroundColor: getLightColor(column.color) }"
  >
    <div 
      class="column-header"
      :data-title="column.title"
      :style="{ backgroundColor: getHeaderColor(column.color) }"
    >
      <div class="column-header-content">
        <div class="column-header-left">
          <span class="column-title dark:text-white">{{ column.title }}</span>
          <span class="column-count dark:text-white">{{ columnCount }}</span>
        </div>
        <div class="column-header-right">
          <div v-if="columnTotal > 0" class="column-total dark:text-white">
            {{ formatCurrency(columnTotal) }}
          </div>
          <woot-button
            icon="add"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            class="add-contact-btn"
            @click="addContactToStage"
            v-tooltip.top="$t('KANBAN.ADD_CONTACT_TO_STAGE', { stage: column.title })"
          >
          </woot-button>
        </div>
      </div>
    </div>
    <div 
      ref="columnContent"
      class="column-content"
      @scroll="handleScroll"
    >
      <draggable
        v-model="columnItems"
        class="column-items"
        :data-column-id="column.id"
        :data-column-title="column.title"
        group="items"
        animation="100"
        easing="cubic-bezier(0.25, 0.46, 0.45, 0.94)"
        ghost-class="ghost-card"
        chosen-class="chosen-card"
        drag-class="dragging-card"
        @start="onDragStart"
        @end="onItemMoved"
      >
        <kanban-card
          v-for="contact in itemsForDrag"
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
          @open-card-modal="$emit('open-card-modal', $event)"
        />
        <div v-if="!columnItems.length" class="empty-column">
          <p>{{ $t('KANBAN.NO_CONTACTS') }}</p>
        </div>
      </draggable>
      <!-- Intersection Observer para carregar mais itens -->
      <intersection-observer
        v-if="hasMoreItems && !isLoadingMore"
        :options="infiniteLoaderOptions"
        @observed="loadMoreItems"
      />
      <!-- Indicador de carregamento -->
      <div v-if="isLoadingMore" class="loading-more-indicator">
        <spinner size="small" />
      </div>
    </div>
  </div>
</template>

<script>
import draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';
import IntersectionObserver from 'dashboard/components/IntersectionObserver.vue';
import Spinner from 'shared/components/Spinner.vue';
import { getDealValue } from '../utils/pipelinePositionsHelper';

export default {
  name: 'KanbanColumn',
  components: {
    draggable,
    KanbanCard,
    IntersectionObserver,
    Spinner,
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
    },
    columnStats: {
      type: Object,
      default: null
    }
  },
  data() {
    return {
      itemsPerPage: 5, // Quantidade de itens por página
      currentPage: 1, // Página atual
      isLoadingMore: false, // Flag para indicar carregamento
      scrollDebounce: null, // Debounce para eventos de scroll
      isDragging: false, // Flag para indicar se está arrastando (renderiza todos os itens)
    };
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
    // Contador de cards: usa stats do backend se disponível, senão usa items.length
    columnCount() {
      if (this.columnStats && this.columnStats.count !== undefined) {
        return this.columnStats.count;
      }
      return this.columnItems.length;
    },
    // Total monetário da coluna: usa stats do backend se disponível, senão calcula localmente
    columnTotal() {
      if (this.columnStats && this.columnStats.total_value !== undefined) {
        return parseFloat(this.columnStats.total_value) || 0;
      }
      // Fallback: calcular localmente baseado nos itens carregados
      return this.columnItems.reduce((total, contact) => {
        const dealValue = getDealValue(contact, this.pipelineId) || 0;
        return total + parseFloat(dealValue);
      }, 0);
    },
    // Itens visíveis baseados na paginação virtual
    visibleItems() {
      const startIndex = 0;
      const endIndex = this.currentPage * this.itemsPerPage;
      return this.columnItems.slice(startIndex, endIndex);
    },
    // Itens para renderizar durante o drag (todos os itens) ou paginação normal
    itemsForDrag() {
      // Durante o drag, mostrar TODOS os itens para permitir posicionamento preciso
      // Fora do drag, usar paginação virtual para melhor performance
      return this.isDragging ? this.columnItems : this.visibleItems;
    },
    // Verifica se há mais itens para carregar (apenas quando não está arrastando)
    hasMoreItems() {
      return !this.isDragging && this.columnItems.length > this.visibleItems.length;
    },
    // Opções para o IntersectionObserver
    infiniteLoaderOptions() {
      return {
        root: this.$refs.columnContent || null,
        rootMargin: '200px 0px 200px 0px', // Carregar quando estiver a 200px do final
      };
    },
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
    onDragStart() {
      // Ativar flag de drag imediatamente para renderizar todos os itens
      // Isso permite posicionamento preciso durante o drag
      this.isDragging = true;
    },
    onItemMoved(event) {
      // Resetar flag de drag
      this.isDragging = false;
      
      if (!event || !event.item) return;
      
      const contactId = parseInt(event.item.getAttribute('data-contact-id'), 10);
      const sourceColumnId = event.from.getAttribute('data-column-id');
      const targetColumnId = event.to.getAttribute('data-column-id');
      const sourceTitle = event.from.getAttribute('data-column-title');
      const targetTitle = event.to.getAttribute('data-column-title');
      
      // Capturar índices exatos para posicionamento preciso
      const oldIndex = event.oldIndex !== undefined ? event.oldIndex : null;
      const newIndex = event.newIndex !== undefined ? event.newIndex : null;
      
      // Emitir evento para o componente pai processar com índices
      this.$emit('item-moved', {
        contactId,
        sourceColumnId,
        targetColumnId,
        sourceColumnTitle: sourceTitle,
        targetColumnTitle: targetTitle,
        oldIndex, // Índice na coluna origem
        newIndex, // Índice na coluna destino (posição exata)
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
    },
    // Carregar mais itens quando o usuário rola até o final
    loadMoreItems() {
      if (this.isLoadingMore || !this.hasMoreItems) return;
      
      this.isLoadingMore = true;
      
      // Simular um pequeno delay para melhor UX (opcional)
      setTimeout(() => {
        this.currentPage += 1;
        this.isLoadingMore = false;
      }, 300);
    },
    // Handler para eventos de scroll (opcional, para otimizações futuras)
    handleScroll(event) {
      // Debounce para evitar muitas chamadas
      clearTimeout(this.scrollDebounce);
      this.scrollDebounce = setTimeout(() => {
        // Pode adicionar lógica de otimização aqui se necessário
      }, 100);
    },
  },
  mounted() {
    // Resetar página quando os itens mudarem
    this.currentPage = 1;
  },
  watch: {
    // Resetar paginação quando os itens da coluna mudarem
    'column.items': {
      handler() {
        this.currentPage = 1;
      },
      deep: true
    }
  }
};
</script>

<style lang="scss" scoped>
.kanban-column {
  flex: 0 0 320px;
  display: flex;
  flex-direction: column;
  height: 100%;
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

.column-header {
  padding: var(--space-small) var(--space-normal);
  font-weight: var(--font-weight-medium);
  cursor: move;
  position: relative;
  border-bottom: 1px solid var(--s-100);
  
  .dark-mode & {
    border-color: var(--b-600);
  }
}

.column-header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.column-header-right {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
}

.column-header-left {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
}

.column-title {
  font-size: var(--font-size-normal);
  color: var(--s-900);
  
  .dark-mode & {
    color: white;
  }
}

.column-count {
  font-size: var(--font-size-mini);
  background-color: rgba(0, 0, 0, 0.05);
  color: var(--s-700);
  border-radius: var(--border-radius-rounded);
  padding: 1px 6px;
  font-weight: var(--font-weight-medium);
  
  .dark-mode & {
    background-color: rgba(255, 255, 255, 0.1);
    color: white;
  }
}

.column-total {
  font-size: var(--font-size-mini);
  color: var(--s-500);
  font-weight: var(--font-weight-normal);
  opacity: 0.95;
  
  .dark-mode & {
    color: white;
    opacity: 0.9;
  }
}

.add-contact-btn {
  opacity: 0.7;
  transition: opacity 0.2s ease;
  
  &:hover {
    opacity: 1;
  }
}

.column-content {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: var(--space-small);
  transition: background-color 0.2s ease;
  
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
  
  // Destacar coluna quando está recebendo um card durante drag
  &.drag-over {
    background-color: rgba(59, 130, 246, 0.05);
    
    .dark-mode & {
      background-color: rgba(59, 130, 246, 0.1);
    }
  }
}

.column-items {
  min-height: 100px;
  display: flex;
  flex-direction: column;
  gap: var(--space-small);
  position: relative;
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
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: var(--border-radius-normal);
  border: 1px dashed var(--s-200);
  
  .dark-mode & {
    color: var(--s-400);
    background-color: rgba(255, 255, 255, 0.03);
    border-color: var(--b-500);
  }
  
  p {
    margin: 0;
  }
}

.ghost-card {
  opacity: 0.2;
  background: var(--w-50);
  border: 2px dashed var(--w-500);
  transform: rotate(2deg);
  transition: opacity 0.2s ease;
  
  .dark-mode & {
    background: var(--b-700);
    border-color: var(--w-400);
  }
}

.chosen-card {
  cursor: grabbing !important;
  transform: scale(1.05);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  z-index: 1000;
}

.dragging-card {
  opacity: 0.9;
  transform: rotate(-2deg) scale(1.02);
  cursor: grabbing !important;
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.25);
  z-index: 1000;
}


.loading-more-indicator {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-small);
}
</style> 