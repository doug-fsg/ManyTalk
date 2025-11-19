<template>
  <div
    class="group/card relative bg-white dark:bg-slate-900 rounded-lg p-4 shadow-sm dark:shadow-xl dark:shadow-black/20 mb-2 cursor-pointer transition-all duration-200 border-none dark:border dark:border-slate-800 hover:shadow-md hover:-translate-y-0.5 hover:bg-slate-50 dark:hover:bg-slate-800 dark:hover:border-slate-700"
    :class="{ 
      'opacity-70 pointer-events-none': isUpdating,
      'shadow-red-100 dark:shadow-red-900/20 border-l-[3px] border-l-red-400 dark:border-l-red-500': hasError,
      'z-10 shadow-lg dark:shadow-2xl': isExpanded,
      'border-l-4 border-l-green-500 bg-green-50/20 dark:bg-green-950/40 hover:bg-green-50/50 dark:hover:bg-green-950/60': winLostStatus === 'won',
      'border-l-4 border-l-red-500 bg-red-50/20 dark:bg-red-950/40 hover:bg-red-50/50 dark:hover:bg-red-950/60': winLostStatus === 'lost'
    }"
    :data-contact-id="contact.id"
    :data-contact-name="contact.name"
    @click="openCardModal"
  >
    <div class="mb-2 flex items-start justify-between relative">
      <span class="font-medium block mb-0.5 flex-grow pr-[60px] text-slate-900 dark:text-white">{{ contact.name }}</span>
      <span 
        v-if="
          contact.additional_attributes &&
          contact.additional_attributes.company
        "
        class="text-sm text-slate-600 dark:text-white block"
      >
        {{ contact.additional_attributes.company }}
      </span>
      <div class="hidden group-hover/card:flex gap-2 absolute top-0 right-0 z-10">
        <!-- Botões principais sempre visíveis -->
        <span 
          class="cursor-pointer p-1 inline-flex items-center justify-center rounded text-slate-600 dark:text-slate-300 transition-all duration-200 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-blue-500 dark:hover:text-blue-400" 
          @click.stop="$emit('view')"
          v-tooltip="$t('KANBAN.VIEW_CONTACT')"
        >
          <fluent-icon icon="contact-card" size="14" />
        </span>
        <span 
          class="cursor-pointer p-1 inline-flex items-center justify-center rounded text-slate-600 dark:text-slate-300 transition-all duration-200 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-green-500 dark:hover:text-green-400" 
          @click.stop="toggleValueInput"
          v-tooltip="dealValue ? $t('KANBAN.CARD.EDIT_DEAL_VALUE') : $t('KANBAN.CARD.ADD_DEAL_VALUE')"
        >
          <fluent-icon icon="tag" size="14" />
        </span>

        <!-- Menu dropdown para outras ações -->
        <div class="relative inline-flex">
          <span 
            class="cursor-pointer p-1 inline-flex items-center justify-center rounded text-slate-600 dark:text-slate-300 transition-all duration-200 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-700 dark:hover:text-white" 
            @click.stop="toggleActionsMenu"
            v-tooltip="'Mais ações'"
          >
            <fluent-icon icon="more-vertical" size="14" />
          </span>

          <!-- Dropdown menu -->
          <div v-if="showActionsMenu" class="absolute top-full right-0 mt-1 bg-white dark:bg-slate-800 rounded-md shadow-lg dark:shadow-2xl dark:shadow-black/40 border border-slate-200 dark:border-slate-700 z-[9999] min-w-[180px] overflow-hidden" @click.stop>
            <!-- Win/Lost Actions -->
            <div
              v-if="!winLostStatus"
              class="flex items-center gap-1.5 px-3 py-1.5 cursor-pointer text-slate-800 dark:text-white text-xs transition-all duration-200 hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="handleWinAction"
            >
              <fluent-icon icon="checkmark-circle" size="12" />
              <span>Marcar como Ganho</span>
            </div>
            <div
              v-if="!winLostStatus"
              class="flex items-center gap-1.5 px-3 py-1.5 cursor-pointer text-slate-800 dark:text-white text-xs transition-all duration-200 hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="handleLostAction"
            >
              <fluent-icon icon="dismiss-circle" size="12" />
              <span>Marcar como Perdido</span>
            </div>

            <!-- Undo Win/Lost Action -->
            <div
              v-if="winLostStatus"
              class="flex items-center gap-1.5 px-3 py-1.5 cursor-pointer text-slate-800 dark:text-white text-xs transition-all duration-200 hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="handleUndoAction"
            >
              <fluent-icon icon="arrow-undo" size="12" />
              <span>Desfazer {{ winLostStatus === 'won' ? 'Ganho' : 'Perdido' }}</span>
            </div>

            <div class="h-px bg-slate-100 dark:bg-slate-700 my-1"></div>

            <div
              class="flex items-center gap-1.5 px-3 py-1.5 cursor-pointer text-red-600 dark:text-red-400 text-xs transition-all duration-200 hover:bg-red-50 dark:hover:bg-red-950/30 hover:text-red-700 dark:hover:text-red-300"
              @click="handleRemoveAction"
            >
              <fluent-icon icon="dismiss" size="12" />
              <span>{{ $t('KANBAN.REMOVE_CARD') }}</span>
            </div>
          </div>
        </div>
      </div>
      <!-- ID do contato oculto para garantir que esteja acessível via DOM -->
      <span class="hidden" style="display: none">
        {{contact.id}}
      </span>
    </div>
    <div class="mb-3">
      <div v-if="contact.email" class="flex items-center text-sm mb-1">
        <span class="mr-1.5 text-slate-500 dark:text-slate-400 text-sm"><i class="icon-mail" /></span>
        <span class="whitespace-nowrap overflow-hidden text-ellipsis text-slate-700 dark:text-slate-200">{{ contact.email }}</span>
      </div>
      <div v-if="contact.phone_number" class="flex items-center text-sm mb-1">
        <span class="mr-1.5 text-slate-500 dark:text-slate-400 text-sm"><i class="icon-phone" /></span>
        <span class="whitespace-nowrap overflow-hidden text-ellipsis text-slate-700 dark:text-slate-200">{{ contact.phone_number }}</span>
      </div>
      
      <!-- Valor do Negócio -->
      <div v-if="dealValue" class="flex items-center text-sm mb-1 mt-2 pt-2 border-t border-dotted border-black/5 dark:border-white/10 opacity-75">
        <span class="mr-1.5 text-slate-500 dark:text-slate-400 text-[10px]">
          <fluent-icon icon="tag" size="12" />
        </span>
        <span class="text-xs text-slate-600 dark:text-slate-300 font-normal">
          {{ formatCurrency(dealValue) }}
        </span>
      </div>
      
      <!-- Tempo na etapa -->
      <div v-if="stageTimeDisplay" class="flex items-center text-sm mb-1 mt-2 pt-2 border-t border-dotted border-black/5 dark:border-white/10 opacity-75">
        <span class="mr-1.5 text-slate-500 dark:text-slate-400 text-[10px]">
          <fluent-icon icon="clock" size="12" />
        </span>
        <span 
          class="text-xs font-normal" 
          :class="{
            'text-slate-600 dark:text-slate-300': stageTimeClass === 'time-normal',
            'text-yellow-500 dark:text-yellow-400': stageTimeClass === 'time-warning',
            'text-red-500 dark:text-red-400 font-medium': stageTimeClass === 'time-overdue'
          }"
          :title="stageTimeTooltip"
        >
          {{ stageTimeDisplay }}
        </span>
      </div>
      
      <!-- Win/Lost Status -->
      <div v-if="winLostStatus" class="flex items-center text-sm mb-1 mt-2 pt-2 border-t border-dotted border-black/5 dark:border-white/10">
        <span 
          class="mr-1.5 text-[10px]"
          :class="{
            'text-green-600 dark:text-green-400': winLostStatus === 'won',
            'text-red-600 dark:text-red-400': winLostStatus === 'lost'
          }"
        >
          <fluent-icon :icon="winLostIcon" size="12" />
        </span>
        <span 
          class="text-xs font-medium"
          :class="{
            'text-green-600 dark:text-green-400': winLostStatus === 'won',
            'text-red-600 dark:text-red-400': winLostStatus === 'lost'
          }"
        >
          {{ winLostLabel }} • {{ winLostDate }}
        </span>
      </div>
    </div>

    <!-- Input de valor flutuante -->
    <div v-if="showValueInput" class="absolute top-[30px] right-2.5 bg-white dark:bg-slate-800 rounded-md shadow-md dark:shadow-2xl dark:shadow-black/40 border border-slate-200 dark:border-slate-700 z-[9998] p-2" @click.stop>
      <div class="flex items-center gap-2">
        <input 
          ref="valueInput"
          v-model="editingValue" 
          type="number" 
          min="0" 
          step="0.01"
          class="w-[120px] p-2 border border-slate-200 dark:border-slate-600 rounded text-sm focus:outline-none focus:border-blue-500 dark:bg-slate-900 dark:text-white dark:focus:border-blue-400"
          :placeholder="$t('KANBAN.CARD.DEAL_VALUE_MODAL.PLACEHOLDER')"
          @keyup.enter="saveValue"
          @keyup.esc="cancelValueEdit"
        />
        <div class="flex gap-1">
          <span class="cursor-pointer w-5 h-5 flex items-center justify-center rounded bg-green-100 dark:bg-green-900/40 text-green-600 dark:text-green-400 hover:bg-green-200 dark:hover:bg-green-900/60" @click="saveValue">
            <fluent-icon icon="checkmark" size="14" />
          </span>
          <span class="cursor-pointer w-5 h-5 flex items-center justify-center rounded bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600" @click="cancelValueEdit">
            <fluent-icon icon="dismiss" size="14" />
        </span>
        </div>
      </div>
    </div>

    <div class="flex justify-between items-center text-sm">
      <div class="flex gap-1 flex-wrap">
        <span 
          v-for="(label, index) in (contact.labels || []).slice(
            0,
            2
          )" 
          :key="index"
          class="px-2 py-0.5 rounded-full text-white text-[11px]"
          :style="{ backgroundColor: getLabelColor(label) }"
        >
          {{ label }}
        </span>
        <span 
          v-if="contact.labels && contact.labels.length > 2" 
          class="px-2 py-0.5 rounded-full bg-slate-200 dark:bg-slate-700 text-slate-800 dark:text-slate-200 text-[11px]"
        >
          +{{ contact.labels.length - 2 }}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <!-- Etiquetas primeiro -->
        <div 
          v-if="allLabels.length" 
          class="flex items-center gap-1 flex-wrap"
        >
          <!-- Etiquetas usando woot-label -->
          <woot-label
            v-for="label in displayedLabelsInBadge"
            :key="label"
            :title="label"
            :color="getLabelColor(label)"
            variant="smooth"
            small
            class="!mb-0"
            @click.stop
          />
          
          <!-- Botão "Ver mais" -->
          <woot-button
            v-if="hasMoreLabels"
            :title="showAllLabels ? 'Ocultar etiquetas' : 'Mostrar etiquetas'"
            class="!mb-0 flex-shrink-0"
            color-scheme="secondary"
            variant="hollow"
            :icon="showAllLabels ? 'chevron-up' : 'chevron-down'"
            size="tiny"
            @click.stop="showAllLabels = !showAllLabels"
          />
        </div>
        
        <!-- Badge do agente responsável -->
        <div 
          v-if="lastConversationAssignee"
          class="flex items-center bg-slate-100 dark:bg-slate-800 rounded-full p-0 text-[10px] font-medium text-slate-700 dark:text-slate-200 cursor-pointer transition-all duration-200 w-5 h-5 justify-center hover:bg-slate-200 dark:hover:bg-slate-700 hover:scale-105"
          v-tooltip="`Responsável: ${lastConversationAssignee.name}`"
          @click.stop
        >
          <img 
            v-if="lastConversationAssignee.thumbnail" 
            :src="lastConversationAssignee.thumbnail" 
            :alt="lastConversationAssignee.name"
            class="w-[18px] h-[18px] rounded-full object-cover object-center flex-shrink-0"
          />
          <span 
            v-else 
            class="text-[10px] font-semibold tracking-wider"
          >
            {{ getAssigneeInitials(lastConversationAssignee) }}
          </span>
        </div>
      </div>
    </div>
    <div v-if="isUpdating" class="absolute inset-0 bg-white/50 dark:bg-black/50 flex items-center justify-center rounded-lg">
      <span class="inline-block text-slate-600 dark:text-white">
        <i class="icon-refresh animate-spin"></i>
      </span>
    </div>

    <!-- Novo botão expansível -->
    <div 
      class="absolute -bottom-2.5 left-1/2 -translate-x-1/2 w-10 h-5 flex flex-col items-center justify-center cursor-pointer bg-white dark:bg-slate-800 rounded-b-md transition-all duration-200 z-[5] border border-slate-100 dark:border-slate-700 border-t-0 shadow-sm hover:bg-slate-50 dark:hover:bg-slate-700"
      :class="{ 'bg-slate-50 dark:bg-slate-700': isExpanded }"
      @click.stop="toggleConversations"
      v-tooltip="isExpanded ? $t('KANBAN.CARD.HIDE_CONVERSATIONS') : $t('KANBAN.CARD.VIEW_CONVERSATIONS')"
    >
      <div class="w-5 h-0.5 bg-slate-200 dark:bg-slate-600 rounded-sm mb-0.5 transition-colors" :class="{ 'bg-slate-300 dark:bg-slate-500': isExpanded }"></div>
      <fluent-icon 
        :icon="isExpanded ? 'chevron-up' : 'chevron-down'" 
        size="12"
        class="text-slate-500 dark:text-slate-300 transition-colors" 
        :class="{ 'text-slate-700 dark:text-white': isExpanded }"
      />
    </div>

    <!-- Seção de conversas -->
    <div v-if="isExpanded" class="mt-3 border-t border-slate-100 dark:border-slate-800 pt-3 relative z-[4] bg-white dark:bg-slate-900 rounded-b-md overflow-hidden">
      <div v-if="isFetchingConversations" class="text-center text-slate-600 dark:text-slate-300 text-sm p-2">
        <span>{{ $t('KANBAN.CARD.LOADING') }}</span>
      </div>
      <div v-else-if="conversations.length === 0" class="text-center text-slate-600 dark:text-slate-300 text-sm p-2">
        <span>{{ $t('KANBAN.CARD.NO_CONVERSATIONS') }}</span>
      </div>
      <div v-else class="p-2 max-h-[300px] overflow-y-auto">
        <div 
          v-for="conversation in sortedConversations" 
          :key="conversation.id"
          class="p-2 border-b border-slate-100 dark:border-slate-800 cursor-pointer transition-colors duration-200 hover:bg-slate-50 dark:hover:bg-slate-800 last:border-b-0"
          @click.stop="openConversation(conversation)"
        >
          <div class="flex justify-between items-center mb-1">
            <span 
              class="text-[11px] px-2 py-0.5 rounded-xl font-medium transition-all duration-200"
              :style="{
                backgroundColor: getStatusColor(conversation.status).bg,
                color: getStatusColor(conversation.status).text
              }"
            >
              {{ getStatusLabel(conversation.status) }}
            </span>
            <span class="text-[11px] text-slate-500 dark:text-slate-400">{{ formatTime(conversation.created_at) }}</span>
          </div>
          <div class="text-xs text-slate-700 dark:text-slate-200 whitespace-nowrap overflow-hidden text-ellipsis">
            {{ getMessageContent(conversation) }}
          </div>
        </div>
        <div v-if="conversations.length > 5" class="p-2 text-center text-xs text-slate-500 dark:text-slate-400 bg-slate-50 dark:bg-slate-800/50 border-t border-slate-100 dark:border-slate-800">
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
import WootLabel from 'dashboard/components/ui/Label.vue';

export default {
  name: 'KanbanCard',
  components: {
    FluentIcon,
    WootLabel,
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
      showAllLabels: false,
      showActionsMenu: false,
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
    lastOpenConversation() {
      return this.conversations.find(conv => conv.status === 'open') || null;
    },
    lastConversationAssignee() {
      return this.lastOpenConversation?.meta?.assignee || null;
    },
    conversationLabels() {
      return this.lastOpenConversation?.labels || [];
    },
    allLabels() {
      // Combina etiquetas da conversa e do contato, removendo duplicatas
      const contactLabels = this.contact.labels || [];
      const allLabelsList = [...this.conversationLabels, ...contactLabels];
      return [...new Set(allLabelsList)];
    },
    displayedLabelsInBadge() {
      if (this.showAllLabels || this.allLabels.length <= 2) {
        return this.allLabels;
      }
      return this.allLabels.slice(0, 2);
    },
    hasMoreLabels() {
      return this.allLabels.length > 2;
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
    getAssigneeInitials(assignee) {
      if (!assignee || !assignee.name) return '';
      const names = assignee.name.trim().split(' ');
      if (names.length === 1) {
        return names[0].charAt(0).toUpperCase();
      }
      return (names[0].charAt(0) + names[names.length - 1].charAt(0)).toUpperCase();
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
    openCardModal() {
      this.$emit('open-card-modal', this.contact);
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
    },
    toggleActionsMenu() {
      this.showActionsMenu = !this.showActionsMenu;
    },
    closeActionsMenu() {
      this.showActionsMenu = false;
    },
    handleWinAction() {
      this.$emit('open-win-modal', { contact: this.contact, currentDealValue: this.dealValue });
      this.closeActionsMenu();
    },
    handleLostAction() {
      this.$emit('open-lost-modal', { contact: this.contact, currentDealValue: this.dealValue });
      this.closeActionsMenu();
    },
    handleUndoAction() {
      this.undoWinLostStatus();
      this.closeActionsMenu();
    },
    handleRemoveAction() {
      this.$emit('remove');
      this.closeActionsMenu();
    }
  },
  mounted() {
    // Carrega conversas automaticamente para exibir assignee e labels
    this.loadConversations();
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
    },
    showActionsMenu(newValue) {
      if (newValue) {
        // Adiciona um event listener global para fechar o menu quando clicar fora
        this.$nextTick(() => {
          document.addEventListener('click', this.closeActionsMenu);
        });
      } else {
        // Remove o event listener quando o menu é fechado
        document.removeEventListener('click', this.closeActionsMenu);
      }
    }
  },
  beforeDestroy() {
    // Limpa os event listeners quando o componente é destruído
    document.removeEventListener('click', this.cancelValueEdit);
    document.removeEventListener('click', this.closeActionsMenu);
  }
};
</script>

<style scoped>
/* Apenas animações necessárias que não são parte do Tailwind */
@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.animate-spin {
  animation: spin 1s linear infinite;
}
</style> 