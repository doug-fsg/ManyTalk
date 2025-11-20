<template>
  <woot-modal
    :show.sync="show"
    :on-close="onClose"
    size=""
    :full-width="false"
  >
    <div class="kanban-card-modal">
      <!-- Header com informações do contato -->
      <div class="modal-header">
        <div class="header-content">
          <thumbnail
            :src="contact.thumbnail"
            size="48px"
            :username="contact.name"
            :status="contact.availability_status"
          />
          <div class="header-info">
            <div class="header-main-info">
              <div class="contact-name-wrapper">
                <h2 class="contact-name">{{ contact.name }}</h2>
                <woot-button
                  icon="open"
                  variant="clear"
                  color-scheme="secondary"
                  size="small"
                  class="contact-profile-button"
                  @click="openContactProfile"
                  v-tooltip.top="$t('CONTACT_PANEL.VIEW_PROFILE')"
                />
              </div>
              <div v-if="stageTimeDisplay" class="stage-time-header" :class="stageTimeClass">
                <fluent-icon icon="clock" size="12" />
                <span>{{ $t('KANBAN.LIST_VIEW.TIME_IN_STAGE') }}: {{ stageTimeDisplay }}</span>
              </div>
            </div>
            <div class="header-contact-info">
              <a
                v-if="contact.email"
                :href="`mailto:${contact.email}`"
                class="contact-link"
              >
                <fluent-icon icon="mail" size="14" />
                <span>{{ contact.email }}</span>
              </a>
              <a
                v-if="contact.phone_number"
                :href="`tel:${contact.phone_number}`"
                class="contact-link"
              >
                <fluent-icon icon="call" size="14" />
                <span>{{ contact.phone_number }}</span>
              </a>
            </div>
          </div>
        </div>
      </div>

      <!-- Seletor de Etapas do Kanban (no topo) -->
      <div class="stage-selector-top">
        <div class="stage-selector-buttons">
          <woot-button
            v-for="stage in availableStages"
            :key="stage"
            :variant="selectedStage === stage ? 'smooth' : 'hollow'"
            :color-scheme="selectedStage === stage ? 'success' : 'secondary'"
            size="small"
            class="stage-button"
            :class="{ 'stage-button-active': selectedStage === stage }"
            @click="selectStage(stage)"
          >
            {{ stage }}
          </woot-button>
        </div>
      </div>

      <!-- Conteúdo do modal em duas colunas -->
      <div class="modal-body-two-columns">
        <!-- Coluna Esquerda: Accordions -->
        <div class="left-column">
          <!-- Seção: Valor do Negócio -->
          <accordion-item
            :title="$t('KANBAN.ADD_CONTACT.FORM.DEAL_VALUE.LABEL')"
            :is-open="accordionSections.dealValue"
            compact
            @click="accordionSections.dealValue = !accordionSections.dealValue"
          >
            <div class="first-accordion-item">
              <div class="value-display">
                <input
                  v-if="isEditingValue"
                  v-model="editingValue"
                  type="number"
                  step="0.01"
                  min="0"
                  class="value-input"
                  @blur="saveValue"
                  @keyup.enter="saveValue"
                  @keyup.esc="cancelEditingValue"
                  ref="valueInput"
                />
                <span v-else class="deal-value">
                  {{ dealValue ? formatCurrency(dealValue) : '-' }}
                </span>
                <woot-button
                  :icon="isEditingValue ? 'checkmark' : 'edit'"
                  variant="clear"
                  size="tiny"
                  @click="toggleEditingValue"
                  v-tooltip="isEditingValue ? $t('COMMON.SAVE') : $t('COMMON.EDIT')"
                />
              </div>
            </div>
          </accordion-item>

          <!-- Seção: Etiquetas -->
          <accordion-item
            :title="$t('CONTACT_PANEL.SIDEBAR_SECTIONS.CONTACT_LABELS')"
            :is-open="accordionSections.labels"
            compact
            @click="accordionSections.labels = !accordionSections.labels"
          >
            <div class="first-accordion-item">
              <contact-labels :contact-id="contact.id" />
            </div>
          </accordion-item>

          <!-- Seção: Atributos do Contato -->
          <accordion-item
            :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_ATTRIBUTES')"
            :is-open="accordionSections.customAttributes"
            compact
            @click="accordionSections.customAttributes = !accordionSections.customAttributes"
          >
            <custom-attributes
              :contact-id="contact.id"
              attribute-type="contact_attribute"
              attribute-class="conversation--attribute"
              attribute-from="kanban_card_modal"
              :custom-attributes="contact.custom_attributes"
              :empty-state-message="$t('CONTACT_PANEL.SIDEBAR_SECTIONS.NO_RECORDS_FOUND')"
              class="even"
            />
          </accordion-item>

          <!-- Seção: Conversas -->
          <accordion-item
            :title="$t('CONTACT_PANEL.SIDEBAR_SECTIONS.PREVIOUS_CONVERSATIONS')"
            :is-open="accordionSections.conversations"
            compact
            @click="accordionSections.conversations = !accordionSections.conversations"
          >
            <div class="first-accordion-item">
              <contact-conversations
                v-if="contact.id"
                :contact-id="contact.id"
                conversation-id=""
              />
            </div>
          </accordion-item>
        </div>

        <!-- Coluna Direita: Observações -->
        <div class="right-column">
          <contact-notes
            v-if="contact.id"
            :contact-id="contact.id"
          />
        </div>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { frontendURL } from 'dashboard/helper/URLHelper';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import ContactLabels from 'dashboard/routes/dashboard/contacts/components/ContactLabels.vue';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import CustomAttributes from 'dashboard/routes/dashboard/conversation/customAttributes/CustomAttributes.vue';
import ContactConversations from 'dashboard/routes/dashboard/conversation/ContactConversations.vue';
import ContactNotes from 'dashboard/modules/notes/NotesOnContactPage.vue';
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import {
  getDealValue,
  getEnteredAt,
  getStage,
  getPipelinePosition
} from '../utils/pipelinePositionsHelper';

export default {
  name: 'KanbanCardModal',
  components: {
    Thumbnail,
    ContactLabels,
    FluentIcon,
    AccordionItem,
    CustomAttributes,
    ContactConversations,
    ContactNotes,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    contact: {
      type: Object,
      required: true,
    },
    pipelineId: {
      type: [Number, String],
      required: true,
    },
    currentStage: {
      type: String,
      default: '',
    },
    stageColor: {
      type: String,
      default: '#6B7280',
    },
    availableStages: {
      type: Array,
      default: () => [],
    },
  },
  data() {
    return {
      isEditingValue: false,
      editingValue: 0,
      selectedStage: '',
      accordionSections: {
        dealValue: true,
        labels: true,
        customAttributes: true,
        conversations: true,
      },
    };
  },
  computed: {
    dealValue() {
      return getDealValue(this.contact, this.pipelineId) || null;
    },
    enteredAt() {
      return getEnteredAt(this.contact, this.pipelineId);
    },
    currentStage() {
      return getStage(this.contact, this.pipelineId);
    },
    stageTimeDisplay() {
      if (!this.enteredAt) return null;
      
      const enteredAtTime = new Date(this.enteredAt).getTime();
      const now = Date.now();
      const timeDiff = now - enteredAtTime;
      
      if (timeDiff < 3600000) {
        const minutes = Math.floor(timeDiff / 60000);
        return `${minutes}m`;
      }
      
      if (timeDiff < 86400000) {
        const hours = Math.floor(timeDiff / 3600000);
        return `${hours}h`;
      }
      
      const days = Math.floor(timeDiff / 86400000);
      return `${days}d`;
    },
    stageTimeClass() {
      if (!this.enteredAt) return '';
      
      const enteredAtTime = new Date(this.enteredAt).getTime();
      const now = Date.now();
      const timeDiff = now - enteredAtTime;
      
      if (timeDiff > 259200000) return 'time-overdue';
      if (timeDiff > 172800000) return 'time-warning';
      return 'time-normal';
    },
  },
  watch: {
    show(newValue) {
      if (newValue) {
        this.selectedStage = this.currentStage;
        // Carregar atributos apenas se ainda não foram carregados
        const attributes = this.$store.getters['attributes/getAttributes'];
        if (!attributes || !attributes.length) {
          this.$store.dispatch('attributes/get', 0);
        }
      }
    },
    currentStage(newValue) {
      this.selectedStage = newValue;
    },
    contact: {
      deep: true,
      immediate: true,
      handler(newContact) {
        // Atualizar selectedStage quando o contato mudar
        if (newContact && newContact.id) {
          this.selectedStage = this.currentStage;
        }
        // Forçar atualização quando o contato mudar para garantir que dealValue seja recalculado
        this.$forceUpdate();
      },
    },
  },
  mounted() {
    this.selectedStage = this.currentStage;
  },
  methods: {
    onClose() {
      this.cancelEditingValue();
      this.$emit('close');
    },
    openContactProfile() {
      const url = frontendURL(
        `accounts/${this.$route.params.accountId}/contacts/${this.contact.id}`
      );
      window.open(url, '_blank');
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
      }).format(value);
    },
    toggleEditingValue() {
      if (this.isEditingValue) {
        this.saveValue();
      } else {
        this.isEditingValue = true;
        this.editingValue = this.dealValue || 0;
        this.$nextTick(() => {
          if (this.$refs.valueInput) {
            this.$refs.valueInput.focus();
          }
        });
      }
    },
    async saveValue() {
      const value = parseFloat(this.editingValue) || 0;
      
      // Obter dados atuais do pipeline_positions
      const currentPosition = getPipelinePosition(this.contact, this.pipelineId);
      const stageId = currentPosition?.stage_id || getStage(this.contact, this.pipelineId);
      const position = currentPosition?.position || 0;
      const enteredAt = currentPosition?.entered_at || new Date().toISOString();
      const metadata = currentPosition?.metadata || {};

      try {
        // Atualizar via pipeline_positions
        await ContactAPI.updatePipelinePosition(
          this.contact.id,
          this.pipelineId,
          stageId,
          position,
          enteredAt,
          value,
          metadata
        );

        this.$emit('value-updated', {
          contactId: this.contact.id,
          value,
        });
        
        this.isEditingValue = false;
      } catch (error) {
        console.error('[KanbanCardModal] Error updating deal value:', error);
      }
    },
    cancelEditingValue() {
      this.isEditingValue = false;
      this.editingValue = 0;
    },
    selectStage(stage) {
      if (stage !== this.currentStage) {
        this.selectedStage = stage;
        this.$emit('stage-changed', {
          contactId: this.contact.id,
          newStage: stage,
          oldStage: this.currentStage,
        });
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.kanban-card-modal {
  @apply flex flex-col w-full m-auto bg-white dark:bg-slate-800;
  max-width: 90vw;
  max-height: 90vh;
  min-width: 60rem;
  
  // Garantir que tooltips apareçam acima do modal
  ::v-deep .tooltip {
    z-index: 10000 !important;
  }
}

// Sobrescrever o tamanho padrão do modal-container para deixar mais largo
::v-deep .modal-container {
  max-width: 95vw !important;
  width: auto !important;
  min-width: 80rem !important;
  padding-left: 1.5rem !important;
  padding-right: 1.5rem !important;
}

.modal-header {
  @apply flex items-center justify-between px-6 py-3 border-b border-slate-200 dark:border-slate-700;

  .header-content {
    @apply flex items-center gap-3 flex-1;

    .header-info {
      @apply flex flex-col flex-1 min-w-0;

      .header-main-info {
        @apply flex items-center gap-2 mb-1 flex-wrap;

        .contact-name-wrapper {
          @apply flex items-center gap-1.5 flex-shrink-0;

          .contact-name {
            @apply text-base font-semibold text-slate-900 dark:text-white m-0;
          }

          .contact-profile-button {
            @apply flex-shrink-0;
          }
        }

        .stage-time-header {
          @apply flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium;

          &.time-normal {
            @apply bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300;
          }

          &.time-warning {
            @apply bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400;
          }

          &.time-overdue {
            @apply bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400;
          }
        }
      }

      .header-contact-info {
        @apply flex flex-col gap-0.5;

        .contact-link {
          @apply flex items-center gap-1.5 text-xs text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 transition-colors no-underline;

          &:hover {
            color: var(--woot-color-woot-500);
            
            .dark-mode & {
              color: var(--woot-color-woot-400);
            }
          }
        }
      }
    }
  }

  .header-actions {
    @apply flex items-center gap-2;
  }
}

// Seletor de etapas no topo
.stage-selector-top {
  @apply px-6 pt-2 pb-2 mb-3 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50;

  .stage-selector-buttons {
    @apply flex flex-wrap gap-2 w-full justify-center;

    .stage-button {
      @apply transition-all;
      
      &.stage-button-active {
        @apply shadow-sm;
        // Verde mais vivo para etapa selecionada (mesma cor do botão success do sistema)
        background-color: #44ce4b !important;
        color: white !important;
        border-color: #44ce4b !important;
        
        &:hover {
          background-color: #3ab841 !important;
          border-color: #3ab841 !important;
        }
        
        .dark-mode & {
          background-color: #44ce4b !important;
          color: white !important;
          border-color: #44ce4b !important;
          
          &:hover {
            background-color: #3ab841 !important;
            border-color: #3ab841 !important;
          }
        }
      }
    }
  }
}

// Layout em duas colunas
.modal-body-two-columns {
  @apply flex flex-1 overflow-hidden;

  .left-column {
    @apply w-2/5 overflow-y-auto border-r border-slate-200 dark:border-slate-700;
    
    // Estilos para garantir que o accordion e componentes internos funcionem corretamente
    ::v-deep .accordion-item {
      @apply bg-white dark:bg-slate-900;
    }

    ::v-deep .contact-conversation--panel {
      @apply bg-white dark:bg-slate-900;
    }

    ::v-deep .conversation {
      @apply bg-white dark:bg-slate-900;
    }
  }

  .right-column {
    @apply w-3/5 overflow-y-auto p-5 bg-slate-25 dark:bg-slate-800;
    
    // Garantir que o modal de exclusão tenha largura própria
    ::v-deep .modal-container {
      max-width: 37.5rem !important;
      width: 37.5rem !important;
      min-width: auto !important;
      padding-left: 0 !important;
      padding-right: 0 !important;
    }
  }
}

.section {
  @apply space-y-3;

  .section-title {
    @apply text-base font-semibold text-slate-900 dark:text-white m-0 pb-2 border-b border-slate-200 dark:border-slate-700;
  }
}

// Espaçamento padrão para o primeiro item dentro de cada accordion (igual ao CustomAttribute)
.first-accordion-item {
  @apply py-3 px-4;
  
  // Reduzir espaçamento quando usado para wrapper simples
  &.simple-wrapper {
    @apply py-2 px-4;
  }
}

// Estilos para o valor do negócio
.value-display {
  @apply flex items-center gap-2;

  .deal-value {
    @apply text-sm font-semibold text-slate-900 dark:text-white;
  }

  .value-input {
    @apply w-32 px-2 py-1 text-sm border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-700 text-slate-900 dark:text-white focus:outline-none;
    
    &:focus {
      border-color: var(--woot-color-woot-500);
      
      .dark-mode & {
        border-color: var(--woot-color-woot-400);
      }
    }
  }
}
</style>
