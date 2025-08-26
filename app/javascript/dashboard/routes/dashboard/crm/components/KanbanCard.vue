<template>
  <div
    class="kanban-card"
    :class="{ 
      'is-updating': isUpdating,
      'has-error': hasError,
      'is-expanded': isExpanded,
      'status-won': winLostStatus === 'won',
      'status-lost': winLostStatus === 'lost'
    }"
    :data-contact-id="contact.id"
    :data-contact-name="contact.name"
    @click="toggleExpand"
  >
    <div class="card-header">
      <span class="card-title">{{ contact.name }}</span>
      <span 
        v-if="
          contact.additional_attributes &&
          contact.additional_attributes.company
        "
        class="card-subtitle"
      >
        {{ contact.additional_attributes.company }}
      </span>
      <div class="card-actions">
        <span 
          class="action-icon view-icon" 
          @click.stop="$emit('view')"
          v-tooltip="$t('KANBAN.VIEW_CONTACT')"
        >
          <fluent-icon icon="contact-card" size="14" />
        </span>
        <span 
          class="action-icon value-icon" 
          @click.stop="toggleValueInput"
          v-tooltip="dealValue ? $t('KANBAN.CARD.EDIT_DEAL_VALUE') : $t('KANBAN.CARD.ADD_DEAL_VALUE')"
        >
          <fluent-icon icon="tag" size="14" />
        </span>
        <!-- Win/Lost Actions -->
        <span
          v-if="!winLostStatus"
          class="action-icon win-icon"
          @click.stop="$emit('open-win-modal', { contact, currentDealValue: dealValue })"
          v-tooltip="'Marcar como Ganho'"
        >
          <fluent-icon icon="checkmark-circle" size="14" />
        </span>
        <span
          v-if="!winLostStatus"
          class="action-icon lost-icon"
          @click.stop="$emit('open-lost-modal', { contact, currentDealValue: dealValue })"
          v-tooltip="'Marcar como Perdido'"
        >
          <fluent-icon icon="dismiss-circle" size="14" />
        </span>

        <!-- Undo Win/Lost Action -->
        <span
          v-if="winLostStatus"
          class="action-icon undo-icon"
          @click.stop="undoWinLostStatus"
          v-tooltip="`Desfazer ${winLostStatus === 'won' ? 'Ganho' : 'Perdido'}`"
        >
          <fluent-icon icon="dismiss-circle" size="14" />
        </span>
        <span 
          class="action-icon remove-icon" 
          @click.stop="$emit('remove')"
          v-tooltip="$t('KANBAN.REMOVE_CARD')"
        >
          <fluent-icon icon="dismiss" size="14" />
        </span>
      </div>
      <!-- ID do contato oculto para garantir que esteja acessível via DOM -->
      <span class="hidden-contact-id" style="display: none">
        {{contact.id}}
      </span>
    </div>
    <div class="card-content">
      <div v-if="contact.email" class="card-info">
        <span class="info-icon"><i class="icon-mail" /></span>
        <span class="info-value">{{ contact.email }}</span>
      </div>
      <div v-if="contact.phone_number" class="card-info">
        <span class="info-icon"><i class="icon-phone" /></span>
        <span class="info-value">{{ contact.phone_number }}</span>
      </div>
      
      <!-- Valor do Negócio -->
      <div class="card-info deal-value" v-if="dealValue">
        <span class="info-icon">
          <fluent-icon icon="tag" size="12" />
        </span>
        <span class="info-value">
          {{ formatCurrency(dealValue) }}
        </span>
      </div>
      
      <!-- Tempo na etapa -->
      <div class="card-info stage-time" v-if="stageTimeDisplay">
        <span class="info-icon">
          <fluent-icon icon="clock" size="12" />
        </span>
        <span class="info-value" :class="stageTimeClass" :title="stageTimeTooltip">
          {{ stageTimeDisplay }}
        </span>
      </div>
      
      <!-- Win/Lost Status -->
      <div v-if="winLostStatus" class="card-info win-lost-status" :class="winLostStatusClass">
        <span class="info-icon">
          <fluent-icon :icon="winLostIcon" size="12" />
        </span>
        <span class="info-value">
          {{ winLostLabel }} • {{ winLostDate }}
        </span>
      </div>
    </div>

    <!-- Input de valor flutuante -->
    <div v-if="showValueInput" class="value-input-popup" @click.stop>
      <div class="value-input-container">
        <input 
          ref="valueInput"
          v-model="editingValue" 
          type="number" 
          min="0" 
          step="0.01"
          class="value-input"
          :placeholder="$t('KANBAN.CARD.DEAL_VALUE_MODAL.PLACEHOLDER')"
          @keyup.enter="saveValue"
          @keyup.esc="cancelValueEdit"
        />
        <div class="value-input-actions">
          <span class="value-action-btn save-btn" @click="saveValue">
            <fluent-icon icon="checkmark" size="14" />
          </span>
          <span class="value-action-btn cancel-btn" @click="cancelValueEdit">
            <fluent-icon icon="dismiss" size="14" />
        </span>
        </div>
      </div>
    </div>

    <div class="card-footer">
      <div class="card-labels">
        <span 
          v-for="(label, index) in (contact.labels || []).slice(
            0,
            2
          )" 
          :key="index"
          class="label-pill"
          :style="{ backgroundColor: getLabelColor(label) }"
        >
          {{ label }}
        </span>
        <span 
          v-if="contact.labels && contact.labels.length > 2" 
          class="label-pill more-labels"
        >
          +{{ contact.labels.length - 2 }}
        </span>
      </div>
      <span class="last-activity">
        {{ getLastActivityTime(contact) }}
      </span>
    </div>
    <div v-if="isUpdating" class="card-overlay">
      <span class="updating-indicator">
        <i class="icon-refresh spinning"></i>
      </span>
    </div>

    <!-- Novo botão expansível -->
    <div 
      class="conversation-expander"
      @click.stop="toggleConversations"
      v-tooltip="isExpanded ? $t('KANBAN.CARD.HIDE_CONVERSATIONS') : $t('KANBAN.CARD.VIEW_CONVERSATIONS')"
    >
      <div class="expander-line"></div>
      <fluent-icon 
        :icon="isExpanded ? 'chevron-up' : 'chevron-down'" 
        size="12"
        class="expander-icon"
      />
    </div>

    <!-- Seção de conversas -->
    <div v-if="isExpanded" class="conversations-preview">
      <div v-if="isFetchingConversations" class="conversations-loading">
        <span class="loading-text">{{ $t('KANBAN.CARD.LOADING') }}</span>
      </div>
      <div v-else-if="conversations.length === 0" class="no-conversations">
        <span>{{ $t('KANBAN.CARD.NO_CONVERSATIONS') }}</span>
      </div>
      <div v-else class="conversations-list">
        <div 
          v-for="conversation in sortedConversations" 
          :key="conversation.id"
          class="conversation-item"
          @click.stop="openConversation(conversation)"
        >
          <div class="conversation-header">
            <span 
              class="status-tag"
              :style="{
                backgroundColor: getStatusColor(conversation.status).bg,
                color: getStatusColor(conversation.status).text
              }"
            >
              {{ getStatusLabel(conversation.status) }}
            </span>
            <span class="conversation-time">{{ formatTime(conversation.created_at) }}</span>
          </div>
          <div class="conversation-preview">
            {{ getMessageContent(conversation) }}
          </div>
        </div>
        <div v-if="conversations.length > 5" class="more-conversations">
          <span>{{ $t('KANBAN.CARD.MORE_CONVERSATIONS', { count: conversations.length - 5 }) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { formatUnixDate } from 'shared/helpers/DateHelper';
import { getRandomColor } from 'dashboard/helper/labelColor';
import { frontendURL } from 'dashboard/helper/URLHelper';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';

export default {
  name: 'KanbanCard',
  components: {
    FluentIcon,
  },
  props: {
    contact: {
      type: Object,
      required: true
    },
    isUpdating: {
      type: Boolean,
      default: false
    },
    hasError: {
      type: Boolean,
      default: false
    },
    pipelineId: {
      type: [Number, String],
      required: true
    }
  },
  data() {
    return {
      colorMap: {},
      isExpanded: false,
      isLoadingConversations: false,
      showValueInput: false,
      editingValue: 0,
    };
  },
  computed: {
    conversations() {
      return this.$store.state.contactConversations.records[this.contact.id] || [];
    },
    isFetchingConversations() {
      return this.$store.state.contactConversations.uiFlags.isFetching;
    },
    sortedConversations() {
      const sorted = [...this.conversations].sort((a, b) => {
        if (a.status === 'open' && b.status !== 'open') return -1;
        if (b.status === 'open' && a.status !== 'open') return 1;
        return b.created_at - a.created_at;
      });
      return sorted.slice(0, 5);
    },
    getStatusLabel() {
      return (status) => {
        const labels = {
          open: this.$t('KANBAN.CARD.STATUS.OPEN'),
          resolved: this.$t('KANBAN.CARD.STATUS.RESOLVED'),
          pending: this.$t('KANBAN.CARD.STATUS.PENDING'),
          snoozed: this.$t('KANBAN.CARD.STATUS.SNOOZED')
        };
        return labels[status] || status;
      };
    },
    getStatusColor() {
      return (status) => {
        const colors = {
          open: {
            bg: '#E3F6EC',
            text: '#1F7B4D'
          },
          resolved: {
            bg: '#E5EFFF',
            text: '#1F4ED7'
          },
          pending: {
            bg: '#FFF3E5',
            text: '#C25700'
          },
          snoozed: {
            bg: '#F3F3F3',
            text: '#4A4A4A'
          }
        };
        return colors[status] || { bg: '#F3F3F3', text: '#4A4A4A' };
      };
    },
    kanbanData() {
      const additionalAttributes = this.contact.additional_attributes || {};
      return additionalAttributes.kanban || {};
    },
    pipelineData() {
      return this.kanbanData[this.pipelineId] || {};
    },
    dealValue() {
      const deal = this.pipelineData.deal || {};
      return deal.value;
    },
    stageTracking() {
      return this.pipelineData.stage_tracking || {};
    },
    currentStage() {
      return this.stageTracking.current || {};
    },
    stageTimeDisplay() {
      if (!this.currentStage.entered_at) return null;
      
      const enteredAt = new Date(this.currentStage.entered_at).getTime();
      const now = Date.now();
      const timeDiff = now - enteredAt;
      
      // Menos de 1 hora
      if (timeDiff < 3600000) {
        const minutes = Math.floor(timeDiff / 60000);
        return `${minutes}m`;
      }
      
      // Menos de 1 dia
      if (timeDiff < 86400000) {
        const hours = Math.floor(timeDiff / 3600000);
        return `${hours}h`;
      }
      
      // Mais de 1 dia
      const days = Math.floor(timeDiff / 86400000);
      return `${days}d`;
    },
    stageTimeClass() {
      if (!this.currentStage.entered_at) {
        return '';
      }
      
      const enteredAt = new Date(this.currentStage.entered_at).getTime();
      const now = Date.now();
      const timeDiff = now - enteredAt;
      
      // Mais de 3 dias (72 horas)
      if (timeDiff > 259200000) {
        return 'time-overdue';
      }
      
      // Mais de 2 dias (48 horas)
      if (timeDiff > 172800000) {
        return 'time-warning';
      }
      
      return 'time-normal';
    },
    stageTimeTooltip() {
      if (!this.currentStage.entered_at) return '';
      
      const enteredAt = new Date(this.currentStage.entered_at);
      const formattedDate = enteredAt.toLocaleDateString();
      const formattedTime = enteredAt.toLocaleTimeString();
      
      return `Nesta etapa desde ${formattedDate} ${formattedTime}`;
    },
    winLostData() {
      return this.pipelineData.win_lost || {};
    },
    winLostStatus() {
      return this.winLostData.status || null;
    },
    winLostLabel() {
      if (this.winLostStatus === 'won') return 'Won';
      if (this.winLostStatus === 'lost') return 'Lost';
      return '';
    },
    winLostIcon() {
      if (this.winLostStatus === 'won') return 'checkmark-circle';
      if (this.winLostStatus === 'lost') return 'dismiss-circle';
      return '';
    },
    winLostStatusClass() {
      return {
        'status-won': this.winLostStatus === 'won',
        'status-lost': this.winLostStatus === 'lost',
      };
    },
    winLostDate() {
      if (!this.winLostData.date) return '';
      const date = new Date(this.winLostData.date);
      return date.toLocaleDateString();
    }
  },
  methods: {
    getLabelColor(label) {
      if (!this.colorMap[label]) {
        this.colorMap[label] = getRandomColor(Object.keys(this.colorMap).length);
      }
      return this.colorMap[label];
    },
    getLastActivityTime(contact) {
      if (!contact.last_activity_at) return '';
      return formatUnixDate(contact.last_activity_at);
    },
    async toggleConversations(event) {
      if (event) {
        event.stopPropagation();
      }
      
      this.isExpanded = !this.isExpanded;
      
      if (this.isExpanded) {
        await this.loadConversations();
      }
    },
    async loadConversations() {
      if (!this.contact.id) return;
      
      try {
        await this.$store.dispatch('contactConversations/get', this.contact.id);
      } catch (error) {
        // Em caso de erro, podemos mostrar uma mensagem ou tratar de outra forma
        console.error('Erro ao carregar conversas:', error);
      }
    },
    formatTime(timestamp) {
      return formatUnixDate(timestamp);
    },
    getMessageContent(conversation) {
      if (!conversation.messages || !conversation.messages.length) {
        return this.$t('KANBAN.CARD.NO_MESSAGES');
      }

      // Filtra apenas mensagens de humanos (incoming ou outgoing)
      const humanMessages = conversation.messages.filter(message => 
        message.message_type === 0 || // incoming
        message.message_type === 1    // outgoing
      );

      if (!humanMessages.length) {
        return this.$t('KANBAN.CARD.NO_USER_MESSAGES');
      }

      // Pega a última mensagem de humano
      const lastHumanMessage = humanMessages[0];
      return lastHumanMessage.content || this.$t('KANBAN.CARD.NO_CONTENT');
    },
    openConversation(conversation) {
      if (!conversation.id) return;
      
      const conversationUrl = frontendURL(`accounts/${this.$route.params.accountId}/conversations/${conversation.id}`);
      window.open(conversationUrl, '_blank');
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL'
      }).format(value);
    },
    toggleValueInput() {
      this.showValueInput = !this.showValueInput;
      this.editingValue = this.dealValue || 0;
      
      if (this.showValueInput) {
        this.$nextTick(() => {
          if (this.$refs.valueInput) {
            this.$refs.valueInput.focus();
          }
        });
      }
    },
    saveValue() {
      const value = parseFloat(this.editingValue) || 0;
      
      // Criar estrutura agrupada simplificada
      const additionalAttributes = {
        ...this.contact.additional_attributes,
        kanban: {
          ...(this.contact.additional_attributes?.kanban || {}),
          [this.pipelineId]: {
            ...(this.contact.additional_attributes?.kanban?.[this.pipelineId] || {}),
            deal: {
              value
            }
          }
        }
      };
      
      this.$emit('value-updated', {
        contactId: this.contact.id,
        value,
        additionalAttributes
      });
      
      this.showValueInput = false;
    },
    cancelValueEdit() {
      this.showValueInput = false;
      this.editingValue = this.dealValue || 0;
    },
    toggleExpand() {
      this.isExpanded = !this.isExpanded;
    },
    undoWinLostStatus() {
      // Remove the win_lost data from the contact
      const additionalAttributes = {
        ...this.contact.additional_attributes,
        kanban: {
          ...(this.contact.additional_attributes?.kanban || {}),
          [this.pipelineId]: {
            ...(this.contact.additional_attributes?.kanban?.[this.pipelineId] || {}),
            win_lost: null // Remove the win_lost data
          }
        }
      };

      this.$emit('undo-win-lost', {
        contactId: this.contact.id,
        additionalAttributes
      });
    }
  },
  watch: {
    showValueInput(newValue) {
      if (newValue) {
        // Adiciona um event listener global para fechar o input quando clicar fora
        document.addEventListener('click', this.cancelValueEdit);
      } else {
        // Remove o event listener quando o input é fechado
        document.removeEventListener('click', this.cancelValueEdit);
      }
    }
  },
  beforeDestroy() {
    // Limpa o event listener quando o componente é destruído
    document.removeEventListener('click', this.cancelValueEdit);
  }
};
</script>

<style lang="scss" scoped>
.kanban-card {
  background-color: var(--white);
  border-radius: var(--border-radius-large);
  padding: var(--space-normal);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  margin-bottom: var(--space-smaller);
  cursor: pointer;
  transition: all 0.2s ease;
  position: relative;
  border: none;
  
  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
    background-color: var(--s-50);
    
    .card-actions {
      display: flex;
    }
  }

  &.is-updating {
    opacity: 0.7;
    pointer-events: none;
  }

  &.has-error {
    box-shadow: 0 2px 8px rgba(var(--r-rgb), 0.1);
    border-left: 3px solid var(--r-400);
  }

  &.is-expanded {
    z-index: 10;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
    
    .conversation-expander {
      background: var(--s-50);
      
      .expander-line {
        background: var(--s-300);
      }
      
      .expander-icon {
        color: var(--s-700);
      }
    }
  }

  &.status-won {
    border-left: 4px solid var(--g-500);
    background-color: rgba(34, 197, 94, 0.02);
    
    &:hover {
      background-color: rgba(34, 197, 94, 0.05);
    }
  }

  &.status-lost {
    border-left: 4px solid var(--r-500);
    background-color: rgba(239, 68, 68, 0.02);
    
    &:hover {
      background-color: rgba(239, 68, 68, 0.05);
    }
  }
  
  .dark-mode & {
    background-color: var(--b-700);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
    
    &:hover {
      background-color: var(--b-600);
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    }
    
    &.has-error {
      box-shadow: 0 2px 8px rgba(var(--r-rgb), 0.2);
    }
    
    &.is-expanded {
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
    }

    &.status-won {
      border-left-color: var(--g-400);
      background-color: rgba(34, 197, 94, 0.05);
      
      &:hover {
        background-color: rgba(34, 197, 94, 0.1);
      }
    }

    &.status-lost {
      border-left-color: var(--r-400);
      background-color: rgba(239, 68, 68, 0.05);
      
      &:hover {
        background-color: rgba(239, 68, 68, 0.1);
      }
    }
  }

  .card-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--border-radius-large);
    
    .dark-mode & {
      background: rgba(0, 0, 0, 0.3);
    }
  }

  .updating-indicator {
    .spinning {
      animation: spin 1s linear infinite;
    }
  }
}

.card-header {
  margin-bottom: var(--space-smaller);
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  position: relative;
}

.card-title {
  font-weight: var(--font-weight-medium);
  display: block;
  margin-bottom: 2px;
  flex-grow: 1;
  padding-right: 60px; /* Espaço para os botões de ação */
}

.card-actions {
  display: none;
  gap: 8px;
  position: absolute;
  top: 0;
  right: 0;
  z-index: 10;
}

.action-icon {
  cursor: pointer;
  padding: var(--space-micro);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--border-radius-small);
  color: var(--s-600);
  transition: all 0.2s ease;

  &:hover {
    background-color: var(--s-100);
    color: var(--s-900);
  }

  &.view-icon:hover {
    color: var(--b-500);
  }
  
  &.value-icon:hover {
    color: var(--g-500);
  }

  &.remove-icon:hover {
    color: var(--r-500);
  }

  &.win-icon:hover {
    color: var(--g-500);
  }

  &.lost-icon:hover {
    color: var(--r-500);
  }

  &.undo-icon:hover {
    color: var(--w-500);
    background-color: var(--s-100);
  }
}

.card-subtitle {
  font-size: var(--font-size-small);
  color: var(--s-600);
  display: block;
}

.card-content {
  margin-bottom: var(--space-small);
}

.card-info {
  display: flex;
  align-items: center;
  font-size: var(--font-size-small);
  margin-bottom: 4px;
  
  .info-icon {
    margin-right: 6px;
    color: var(--s-500);
    font-size: 14px;
    
    .dark-mode & {
      color: var(--s-400);
    }
  }
  
  .info-value {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: var(--font-size-small);
}

.card-labels {
  display: flex;
  gap: 4px;
  flex-wrap: wrap;
}

.label-pill {
  padding: 2px 8px;
  border-radius: var(--border-radius-rounded);
  color: var(--white);
  font-size: 11px;
}

.more-labels {
  background-color: var(--s-200);
  color: var(--s-800);
  
  .dark-mode & {
    background-color: var(--b-600);
    color: var(--s-200);
  }
}

.last-activity {
  font-size: 11px;
  color: var(--s-500);
  
  .dark-mode & {
    color: var(--s-400);
  }
}

.value-input-popup {
  position: absolute;
  top: 30px;
  right: 10px;
  background-color: var(--white);
  border-radius: var(--border-radius-normal);
  box-shadow: var(--shadow-medium);
  border: 1px solid var(--s-200);
  z-index: 100;
  padding: var(--space-smaller);
  
  .dark-mode & {
    background-color: var(--b-700);
    border-color: var(--b-600);
  }
}

.value-input-container {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
}

.value-input {
  width: 120px;
  padding: var(--space-smaller);
  border: 1px solid var(--s-200);
  border-radius: var(--border-radius-small);
  font-size: var(--font-size-small);
  
  &:focus {
    outline: none;
    border-color: var(--w-500);
  }
  
  .dark-mode & {
    background-color: var(--b-600);
    border-color: var(--b-500);
    color: var(--s-200);
  }
}

.value-input-actions {
  display: flex;
  gap: 4px;
}

.value-action-btn {
  cursor: pointer;
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--border-radius-small);
  
  &.save-btn {
    background-color: var(--g-100);
    color: var(--g-600);

  &:hover {
      background-color: var(--g-200);
    }
  }
  
  &.cancel-btn {
    background-color: var(--s-100);
    color: var(--s-600);
    
    &:hover {
      background-color: var(--s-200);
    }
  }
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.deal-value {
  margin-top: var(--space-smaller);
  padding-top: var(--space-smaller);
  border-top: 1px dotted rgba(0, 0, 0, 0.05);
  opacity: 0.75;
  
  .info-icon {
    font-size: 10px;
  }
  
  .info-value {
    font-size: var(--font-size-mini);
    color: var(--s-600);
    font-weight: var(--font-weight-normal);
  }
  
  .dark-mode & {
    border-top-color: rgba(255, 255, 255, 0.05);
    
    .info-value {
      color: var(--s-400);
    }
  }
}

.conversation-expander {
  position: absolute;
  bottom: -10px;
  left: 50%;
  transform: translateX(-50%);
  width: 40px;
  height: 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  background: var(--white);
  border-radius: 0 0 var(--border-radius-normal) var(--border-radius-normal);
  transition: all 0.2s ease;
  z-index: 5;
  border: 1px solid var(--s-100);
  border-top: none;
  box-shadow: var(--shadow-small);
  
  .dark-mode & {
    background: var(--b-700);
    border-color: var(--b-600);
  }
  
  &:hover {
    background: var(--s-50);
    
    .expander-line {
      background: var(--s-300);
    }
    
    .expander-icon {
      color: var(--s-700);
    }
    
    .dark-mode & {
      background: var(--b-600);
      
      .expander-line {
        background: var(--s-400);
      }
      
      .expander-icon {
        color: var(--s-300);
      }
    }
  }
}

.expander-line {
  width: 20px;
  height: 2px;
  background: var(--s-200);
  border-radius: 2px;
  margin-bottom: 2px;
  transition: background 0.2s ease;
  
  .dark-mode & {
    background: var(--b-500);
  }
}

.expander-icon {
  color: var(--s-500);
  transition: color 0.2s ease;
  
  .dark-mode & {
    color: var(--s-400);
  }
}

.conversations-preview {
  margin-top: var(--space-small);
  border-top: 1px solid var(--s-100);
  padding-top: var(--space-small);
  position: relative;
  z-index: 4;
  background: var(--white);
  border-radius: 0 0 var(--border-radius-normal) var(--border-radius-normal);
  overflow: hidden;
  
  .dark-mode & {
    background: var(--b-700);
    border-color: var(--b-600);
  }
}

.conversations-loading,
.no-conversations {
  text-align: center;
  color: var(--s-600);
  font-size: var(--font-size-small);
  padding: var(--space-smaller);
}

.conversations-list {
  padding: 8px;
  max-height: 300px;
  overflow-y: auto;

  .conversation-item {
    padding: 8px;
    border-bottom: 1px solid var(--color-border);
    cursor: pointer;
    transition: background-color 0.2s ease;

    &:hover {
      background-color: var(--color-background-light);
    }

    &:last-child {
      border-bottom: none;
    }
  }

  .conversation-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 4px;
  }

  .status-tag {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 12px;
    font-weight: 500;
    transition: all 0.2s ease;
  }

  .conversation-time {
    font-size: 11px;
    color: var(--color-text-light);
  }

  .conversation-preview {
    font-size: 12px;
    color: var(--color-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .more-conversations {
    padding: 8px;
    text-align: center;
    font-size: 12px;
    color: var(--color-text-light);
    background-color: var(--color-background-light);
    border-top: 1px solid var(--color-border);
  }
}

.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease;
}

.slide-enter-from,
.slide-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}

.stage-time {
  margin-top: var(--space-smaller);
  padding-top: var(--space-smaller);
  border-top: 1px dotted rgba(0, 0, 0, 0.05);
  opacity: 0.75;
  
  .info-icon {
    font-size: 10px;
  }
  
  .info-value {
    font-size: var(--font-size-mini);
    color: var(--s-600);
    font-weight: var(--font-weight-normal);
    
    &.time-normal {
      color: var(--s-600);
    }
    
    &.time-warning {
      color: var(--y-500);
    }
    
    &.time-overdue {
      color: var(--r-500);
      font-weight: var(--font-weight-medium);
    }
  }
  
  .dark-mode & {
    border-top-color: rgba(255, 255, 255, 0.05);
    
    .info-value {
      color: var(--s-400);
      
      &.time-normal {
        color: var(--s-400);
      }
      
      &.time-warning {
        color: var(--y-400);
      }
      
      &.time-overdue {
        color: var(--r-400);
      }
    }
  }
}

.win-lost-status {
  margin-top: var(--space-smaller);
  padding-top: var(--space-smaller);
  border-top: 1px dotted rgba(0, 0, 0, 0.05);
  
  .info-icon {
    font-size: 10px;
  }
  
  .info-value {
    font-size: var(--font-size-mini);
    font-weight: var(--font-weight-medium);
  }
  
  &.status-won {
    .info-icon,
    .info-value {
      color: var(--g-600);
    }
  }
  
  &.status-lost {
    .info-icon,
    .info-value {
      color: var(--r-600);
    }
  }
  
  .dark-mode & {
    border-top-color: rgba(255, 255, 255, 0.05);
    
    &.status-won {
      .info-icon,
      .info-value {
        color: var(--g-400);
      }
    }
    
    &.status-lost {
      .info-icon,
      .info-value {
        color: var(--r-400);
      }
    }
  }
}
</style> 