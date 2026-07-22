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
        <div class="header-actions">
          <woot-button
            icon="add"
            size="small"
            variant="smooth"
            color-scheme="primary"
            @click="openNewActivity"
          >
            {{ $t('KANBAN.CARD_MODAL.NEW_ACTIVITY') }}
          </woot-button>
        </div>
      </div>

      <!-- Seletor de Etapas do Kanban (no topo) -->
      <div class="stage-selector-top">
        <div class="stage-selector-buttons">
          <woot-button
            v-for="stage in normalizedStages"
            :key="getStageKey(stage)"
            :variant="selectedStage === getStageName(stage) ? 'smooth' : 'hollow'"
            :color-scheme="selectedStage === getStageName(stage) ? 'success' : 'secondary'"
            size="small"
            class="stage-button"
            :class="{ 'stage-button-active': selectedStage === getStageName(stage) }"
            @click="selectStage(getStageName(stage))"
          >
            {{ getStageName(stage) }}
          </woot-button>
        </div>
      </div>

      <!-- Conteúdo do modal em duas colunas -->
      <div class="modal-body-two-columns">
        <!-- Coluna Esquerda: Accordions -->
        <div class="left-column">
          <!-- Seção: Responsável -->
          <accordion-item
            title="Responsável"
            :is-open="accordionSections.assignee"
            compact
            @click="accordionSections.assignee = !accordionSections.assignee"
          >
            <div v-if="isAdmin" class="multiselect-wrap--small">
              <div v-if="showSelfAssign" class="mb-2">
                <woot-button
                  icon="arrow-right"
                  variant="link"
                  size="small"
                  @click="onSelfAssign"
                >
                  {{ $t('CONVERSATION_SIDEBAR.SELF_ASSIGN') }}
                </woot-button>
              </div>
              <multiselect-dropdown
                :options="agentsList"
                :selected-item="assignedAgent"
                :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')"
                :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
                :no-search-result="
                  $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
                "
                :input-placeholder="
                  $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
                "
                @click="onClickAssignAgent"
              />
            </div>
            <div v-else class="p-4 bg-slate-50 dark:bg-slate-800 rounded-lg">
              <div v-if="cardAssignee" class="flex items-center gap-2">
                <img 
                  v-if="cardAssignee.thumbnail" 
                  :src="cardAssignee.thumbnail" 
                  :alt="cardAssignee.name"
                  class="w-8 h-8 rounded-full object-cover"
                />
                <div v-else class="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center text-sm font-semibold text-slate-700 dark:text-slate-300">
                  {{ getAssigneeInitials(cardAssignee) }}
                </div>
                <span class="text-sm font-medium text-slate-900 dark:text-white">{{ cardAssignee.name }}</span>
              </div>
              <div v-else class="flex flex-col gap-2">
                <span class="text-sm text-slate-500 dark:text-slate-400">Sem dono</span>
                <!-- EXCEÇÃO: Agentes podem atribuir para si mesmos quando o card não tem dono -->
                <woot-button
                  icon="arrow-right"
                  variant="smooth"
                  size="small"
                  @click="onSelfAssign"
                >
                  {{ $t('CONVERSATION_SIDEBAR.SELF_ASSIGN') }}
                </woot-button>
              </div>
            </div>
          </accordion-item>

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

        <!-- Coluna Direita: Tabs (Observações | Atividades) -->
        <div class="right-column">
          <!-- Tabs -->
          <div class="flex gap-2 mb-4 border-b border-slate-200 dark:border-slate-700">
            <button
              :class="[
                'px-4 py-2 text-sm font-medium transition-colors duration-150 border-b-2',
                activeTab === 'timeline'
                  ? 'border-woot-500 text-woot-600 dark:border-woot-400 dark:text-woot-400'
                  : 'border-transparent text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 hover:border-slate-300 dark:hover:border-slate-600'
              ]"
              @click="setActiveTab('timeline')"
            >
              {{ $t('CONTACT_PROFILE.TABS.TIMELINE') }}
            </button>
            <button
              :class="[
                'px-4 py-2 text-sm font-medium transition-colors duration-150 border-b-2',
                activeTab === 'notes'
                  ? 'border-woot-500 text-woot-600 dark:border-woot-400 dark:text-woot-400'
                  : 'border-transparent text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 hover:border-slate-300 dark:hover:border-slate-600'
              ]"
              @click="setActiveTab('notes')"
            >
              {{ $t('CONTACT_PANEL.SIDEBAR_SECTIONS.NOTES') }}
            </button>
            <button
              :class="[
                'px-4 py-2 text-sm font-medium transition-colors duration-150 border-b-2 flex items-center gap-1.5',
                activeTab === 'activities'
                  ? 'border-woot-500 text-woot-600 dark:border-woot-400 dark:text-woot-400'
                  : 'border-transparent text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 hover:border-slate-300 dark:hover:border-slate-600'
              ]"
              @click="setActiveTab('activities')"
            >
              {{ $t('ACTIVITIES.TITLE') }}
              <span
                v-if="overdueActivitiesCount > 0"
                class="px-1.5 py-0.5 rounded-full text-[10px] font-semibold bg-red-50 text-red-700 border border-red-200 dark:bg-red-900/30 dark:text-red-300 dark:border-red-800"
              >
                {{ overdueActivitiesCount }}
              </span>
              <span
                v-else-if="pendingActivitiesCount > 0"
                class="px-1.5 py-0.5 rounded-full text-[10px] font-semibold bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
              >
                {{ pendingActivitiesCount }}
              </span>
            </button>
          </div>

          <!-- Conteúdo das tabs -->
          <div class="tab-content">
            <contact-timeline
              v-if="activeTab === 'timeline' && contact.id"
              ref="contactTimeline"
              :contact-id="contact.id"
              :account-id="currentAccountId"
              :highlight-pipeline-id="pipelineId"
              compact
              @open-activities="openActivitiesFromTimeline"
            />
            <contact-notes
              v-if="activeTab === 'notes' && contact.id"
              :contact-id="contact.id"
            />
            <contact-activities
              v-if="activeTab === 'activities' && contact.id"
              ref="contactActivities"
              :contact-id="contact.id"
              :contact="contact"
              :pipeline-id="pipelineId"
              :highlight-activity-id="effectiveHighlightActivityId"
              @changed="onActivitiesChanged"
            />
          </div>
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
import ContactActivities from './ContactActivities.vue';
import ContactTimeline from '../../contacts/components/profile/ContactTimeline.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import { mapGetters } from 'vuex';
import agentMixin from 'dashboard/mixins/agentMixin';
import {
  getDealValue,
  getEnteredAt,
  getStage,
  getPipelinePosition
} from '../utils/pipelinePositionsHelper';
import {
  getActivityCountForContact,
  resolveCardModalTab,
  storeCardModalTab,
} from '../utils/crmNavigationHelper';

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
    ContactActivities,
    ContactTimeline,
    MultiselectDropdown,
  },
  mixins: [agentMixin],
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
    stageColor: {
      type: String,
      default: '#6B7280',
    },
    availableStages: {
      type: Array,
      default: () => [],
    },
    initialTab: {
      type: String,
      default: null,
    },
    highlightActivityId: {
      type: [Number, String],
      default: null,
    },
  },
  data() {
    return {
      isEditingValue: false,
      editingValue: 0,
      selectedStage: '',
      accordionSections: {
        assignee: true,
        dealValue: true,
        labels: true,
        customAttributes: true,
        conversations: true,
      },
      activeTab: 'timeline',
      localHighlightActivityId: null,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      currentAccountId: 'getCurrentAccountId',
      agents: 'agents/getAgents',
      getPendingCountByContactId: 'activities/getPendingCountByContactId',
      getOverdueCountByContactId: 'activities/getOverdueCountByContactId',
    }),
    pendingActivitiesCount() {
      if (!this.contact?.id) return 0;
      return getActivityCountForContact(
        this.getPendingCountByContactId,
        this.contact.id
      );
    },
    overdueActivitiesCount() {
      if (!this.contact?.id) return 0;
      return getActivityCountForContact(
        this.getOverdueCountByContactId,
        this.contact.id
      );
    },
    hasOverdueActivities() {
      return this.overdueActivitiesCount > 0;
    },
    effectiveHighlightActivityId() {
      return this.localHighlightActivityId || this.highlightActivityId;
    },
    isAdmin() {
      return this.currentUser?.role === 'administrator';
    },
    // Sobrescrever assignableAgents do agentMixin para usar agents/getAgents ao invés de inboxAssignableAgents
    assignableAgents() {
      const allAgents = Array.isArray(this.agents) ? this.agents : [];
      // Filtrar apenas agents confirmados (igual ao inboxAssignableAgents)
      return allAgents.filter(agent => agent && agent.confirmed);
    },
    // Sobrescrever agentsList do agentMixin para adaptar ao contexto CRM
    agentsList() {
      const agents = this.assignableAgents || [];
      const agentsByUpdatedPresence = this.getAgentsByUpdatedPresence(agents);
      const none = this.createNoneAgent;
      const filteredAgentsByAvailability = this.sortedAgentsByAvailability(
        agentsByUpdatedPresence
      );
      const filteredAgents = [
        ...(this.cardAssignee ? [none] : []),
        ...filteredAgentsByAvailability,
      ];
      return filteredAgents;
    },
    // Sobrescrever createNoneAgent para usar id: 0 (padrão do agentMixin)
    createNoneAgent() {
      return {
        confirmed: true,
        name: 'None',
        id: 0,
        role: 'agent',
        account_id: 0,
        email: 'None',
      };
    },
    assignedAgent: {
      get() {
        return this.cardAssignee;
      },
      set(agent) {
        this.changeAssignee(agent);
      },
    },
    showSelfAssign() {
      if (!this.isAdmin) {
        return false;
      }
      if (!this.cardAssignee) {
        return true;
      }
      return false;
    },
    cardAssignee() {
      const position = this.contact.pipeline_positions?.find(
        p => p.pipeline_id === this.pipelineId || p.pipeline_id === parseInt(this.pipelineId, 10)
      );
      return position?.assignee || null;
    },
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
    // Normalizar stages para lidar com objetos {name, color} ou strings
    normalizedStages() {
      if (!Array.isArray(this.availableStages)) return [];
      return this.availableStages;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(newValue) {
        if (newValue) {
          this.selectedStage = this.currentStage;
          this.applyInitialTab();
          const attributes = this.$store.getters['attributes/getAttributes'];
          if (!attributes || !attributes.length) {
            this.$store.dispatch('attributes/get', 0);
          }
          this.$store.dispatch('agents/get');
        }
      },
    },
    initialTab(newValue) {
      if (this.show && newValue) {
        this.applyInitialTab();
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
    // Carregar agents quando o modal é montado
    this.$store.dispatch('agents/get');
  },
  methods: {
    applyInitialTab() {
      this.activeTab = resolveCardModalTab({
        initialTab: this.initialTab,
        hasOverdueActivities: this.hasOverdueActivities,
      });
    },
    setActiveTab(tab) {
      this.activeTab = tab;
      storeCardModalTab(tab);
    },
    openNewActivity() {
      this.setActiveTab('activities');
      this.$nextTick(() => {
        this.$refs.contactActivities?.openCreateForm();
      });
    },
    openActivitiesFromTimeline(activityId) {
      this.localHighlightActivityId = activityId;
      this.setActiveTab('activities');
    },
    onActivitiesChanged() {
      this.$refs.contactTimeline?.refresh?.();
    },
    onSelfAssign() {
      const {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        avatar_url,
      } = this.currentUser;
      const selfAssign = {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        thumbnail: avatar_url,
      };
      // Chamar changeAssignee diretamente para funcionar tanto para admin quanto para agentes
      this.changeAssignee(selfAssign);
    },
    onClickAssignAgent(selectedItem) {
      if (this.assignedAgent && this.assignedAgent.id === selectedItem.id) {
        this.assignedAgent = null;
      } else {
        this.assignedAgent = selectedItem;
      }
    },
    getAssigneeInitials(assignee) {
      if (!assignee || !assignee.name) return '';
      const names = assignee.name.trim().split(' ');
      if (names.length === 1) {
        return names[0].charAt(0).toUpperCase();
      }
      return (names[0].charAt(0) + names[names.length - 1].charAt(0)).toUpperCase();
    },
    async changeAssignee(assignee) {
      const currentPosition = getPipelinePosition(this.contact, this.pipelineId);
      const currentAssigneeId = currentPosition?.assignee?.id || null;
      const assigneeId = (assignee && assignee.id !== 0 && assignee.id !== null && assignee.id !== undefined) ? assignee.id : null;
      
      // Verificar permissão: apenas admin pode trocar dono
      // EXCEÇÃO: Agentes podem atribuir para si mesmos quando o card não tem dono
      if (!this.isAdmin) {
        // Se não é admin, só pode atribuir para si mesmo quando card não tem dono
        const currentUserId = this.currentUser?.id;
        const isSelfAssign = assigneeId === currentUserId;
        const hasNoOwner = currentAssigneeId === null;
        
        if (!(isSelfAssign && hasNoOwner)) {
          useAlert('Sem permissão para trocar dono');
          return;
        }
      }
      
      try {
        const stageId = currentPosition?.stage_id || getStage(this.contact, this.pipelineId);
        const position = currentPosition?.position || 0;
        const enteredAt = currentPosition?.entered_at || new Date().toISOString();
        const dealValue = currentPosition?.deal_value;
        const metadata = currentPosition?.metadata || {};

        await ContactAPI.updatePipelinePosition(
          this.contact.id,
          this.pipelineId,
          stageId,
          position,
          enteredAt,
          dealValue,
          metadata,
          { updateAssignee: true, assigneeId: assigneeId }
        );

        // Atualizar assignee localmente no contato para atualizar o modal imediatamente
        const pipelinePosition = this.contact.pipeline_positions?.find(
          p => p.pipeline_id === this.pipelineId || p.pipeline_id === parseInt(this.pipelineId, 10)
        );
        if (pipelinePosition) {
          // Usar Vue.set para garantir reatividade quando definimos como null
          if (assigneeId) {
            this.$set(pipelinePosition, 'assignee', assignee);
          } else {
            this.$set(pipelinePosition, 'assignee', null);
          }
        }
        
        // Emitir evento para componente pai atualizar kanban
        this.$emit('assignee-updated', {
          contactId: this.contact.id,
          assignee: assigneeId ? assignee : null,
        });
        
        useAlert('Responsável atualizado');
      } catch (error) {
        useAlert('Erro ao atualizar responsável');
      }
    },
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
        // Erro ao atualizar valor do negócio
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
    // Extrair o nome do stage (suporta objeto {name, color} ou string)
    getStageName(stage) {
      if (typeof stage === 'object' && stage !== null) {
        return stage.name || stage.value || String(stage);
      }
      return String(stage);
    },
    // Obter chave única para o stage (para :key no v-for)
    getStageKey(stage) {
      if (typeof stage === 'object' && stage !== null) {
        return stage.name || stage.value || JSON.stringify(stage);
      }
      return String(stage);
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
    
    .tab-content {
      @apply h-full;
    }
    
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
