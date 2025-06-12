<template>
  <div
    class="kanban-card"
    :class="{ 
      'is-updating': isUpdating,
      'has-error': hasError,
      'is-expanded': isExpanded
    }"
    :data-contact-id="contact.id"
    :data-contact-name="contact.name"
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
      v-tooltip="isExpanded ? 'Ocultar conversas' : 'Ver conversas'"
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
        <span class="loading-text">Carregando...</span>
      </div>
      <div v-else-if="conversations.length === 0" class="no-conversations">
        <span>Nenhuma conversa encontrada</span>
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
          <span>+{{ conversations.length - 5 }} conversas</span>
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
    }
  },
  data() {
    return {
      colorMap: {},
      isExpanded: false,
      isLoadingConversations: false,
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
          open: 'Aberta',
          resolved: 'Resolvida',
          pending: 'Pendente',
          snoozed: 'Pausada'
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
        return 'Sem mensagens';
      }

      // Filtra apenas mensagens de humanos (incoming ou outgoing)
      const humanMessages = conversation.messages.filter(message => 
        message.message_type === 0 || // incoming
        message.message_type === 1    // outgoing
      );

      if (!humanMessages.length) {
        return 'Sem mensagens de usuários';
      }

      // Pega a última mensagem de humano
      const lastHumanMessage = humanMessages[0];
      return lastHumanMessage.content || 'Sem conteúdo';
    },
    openConversation(conversation) {
      if (!conversation.id) return;
      
      const conversationUrl = frontendURL(`accounts/${this.$route.params.accountId}/conversations/${conversation.id}`);
      window.open(conversationUrl, '_blank');
    }
  }
};
</script>

<style lang="scss" scoped>
.kanban-card {
  background-color: var(--white);
  border-radius: var(--border-radius-normal);
  box-shadow: var(--shadow-small);
  border: 1px solid var(--s-100);
  padding: var(--space-normal);
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  position: relative;
  
  &:hover {
    transform: translateY(-2px);
    box-shadow: var(--shadow-medium);
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
    border: 1px solid var(--r-400);
  }

  &.is-expanded {
    z-index: 10;
    box-shadow: var(--shadow-medium);
    
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

  &.remove-icon:hover {
    color: var(--r-500);
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

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
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

  &:hover {
    background: var(--s-50);
    
    .expander-line {
      background: var(--s-300);
    }
    
    .expander-icon {
      color: var(--s-700);
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
}

.expander-icon {
  color: var(--s-500);
  transition: color 0.2s ease;
}

.conversations-preview {
  margin-top: var(--space-small);
  border-top: 1px solid var(--s-100);
  padding-top: var(--space-small);
  position: relative;
  z-index: 4;
  background: var(--white);
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
</style> 