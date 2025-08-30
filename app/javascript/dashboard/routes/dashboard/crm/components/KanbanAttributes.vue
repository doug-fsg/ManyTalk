<template>
  <div class="kanban-container" :class="{ 'dark-mode': isDarkMode }">
    <kanban-header
      :pipeline-name="
        selectedAttribute
          ? selectedAttribute.attribute_display_name
          : $t('KANBAN.TITLE')
      "
      :current-view="currentView"
      :pipelines="listTypeAttributes"
      @update:current-view="currentView = $event"
      @select-pipeline="selectPipeline"
      @search="handleSearch"
      @create-new="openCreateAttributeModal"
      @edit-kanban="editKanban"
      @delete-kanban="deleteKanban"
      :win-lost-filter="winLostFilter"
      @win-lost-filter="handleWinLostFilter"
    />

    <div v-if="showPipelineDropdown" class="pipeline-dropdown">
      <div
        v-for="attribute in listTypeAttributes"
        :key="attribute.id"
        class="pipeline-option"
        @click="selectPipeline(attribute)"
      >
        {{ attribute.display_name }}
      </div>
    </div>

    <div
      v-if="
        !selectedAttribute && attributes.length && listTypeAttributes.length
      "
      class="kanban-select-attribute"
    >
      <div class="select-attribute-content">
        <h2>{{ $t('KANBAN.SELECT_ATTRIBUTE') }}</h2>
        <p>{{ $t('KANBAN.SELECT_ATTRIBUTE_DESCRIPTION') }}</p>

        <div class="attribute-list">
          <woot-button
            v-for="attribute in listTypeAttributes"
            :key="attribute.id"
            variant="smooth"
            size="large"
            class="attribute-button"
            @click="selectAttribute(attribute)"
          >
            {{ attribute.attribute_display_name }}
          </woot-button>
        </div>
      </div>
    </div>

    <div
      v-if="
        !selectedAttribute && attributes.length && !listTypeAttributes.length
      "
      class="kanban-select-attribute"
    >
      <div class="select-attribute-content">
        <div class="empty-state-icon">
          <fluent-icon icon="kanban" size="64" />
        </div>
        <h2>{{ $t('KANBAN.NO_KANBAN_ATTRIBUTES') }}</h2>
        <p>{{ $t('KANBAN.CREATE_KANBAN_ATTRIBUTE_DESCRIPTION') }}</p>
        
        <div class="action-buttons">
          <woot-button
            size="large"
            variant="primary"
            icon="add"
            @click="openCreateAttributeModal"
          >
            {{ $t('KANBAN.CREATE_NEW_ATTRIBUTE') }}
          </woot-button>
        </div>
      </div>
    </div>

    <!-- Loading state para o carregamento de contatos -->
    <woot-loading-state v-if="isLoadingContacts" :message="loadingMessage" />

    <div
      v-else-if="selectedAttribute && !uiFlags.isFetching"
      class="kanban-board"
    >
      <div class="kanban-columns-container">
        <draggable
          v-model="columns"
          class="kanban-columns"
          :options="{
            group: 'columns',
            handle: '.column-header',
            animation: 150,
          }"
        >
          <kanban-column
            v-for="column in displayColumns"
            :key="column.id"
            :column="column"
            :pipeline-id="selectedAttribute.id"
            :operation-manager="operationManager"
            @item-moved="onItemMoved"
            @view-contact="openContact"
            @remove-card="removeCardFromKanban"
            @update:items="handleColumnItemsUpdate"
            @open-conversation="openConversation"
            @value-updated="handleDealValueUpdate"
            @win-lost-updated="handleWinLostUpdate"
            @open-win-modal="handleOpenWinModal"
            @open-lost-modal="handleOpenLostModal"
            @undo-win-lost="handleUndoWinLost"
            @add-contact-to-stage="handleAddContactToStage"
          />
        </draggable>
      </div>
    </div>

    <woot-modal :show.sync="showFilterModal" :on-close="closeFilterModal">
      <div class="filter-modal">
        <woot-modal-header
          :header-title="$t('KANBAN.FILTER_CONTACTS')"
          :header-content="$t('KANBAN.FILTER_DESCRIPTION')"
        />
        <div class="filter-content">
          <!-- Implementar filtros de contato aqui -->
        </div>
        <div class="modal-footer">
          <woot-button variant="clear" @click="closeFilterModal">
            {{ $t('COMMON.CANCEL') }}
          </woot-button>
          <woot-button variant="primary" @click="applyFilters">
            {{ $t('COMMON.APPLY') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <create-attribute-modal
      :show.sync="showCreateAttributeModal"
      @attribute-created="handleAttributeCreated"
      @create-error="handleCreateError"
    />

    <!-- Modal de confirmação para remover card -->
    <woot-delete-modal
      :show.sync="showRemoveCardModal"
      :on-close="closeRemoveCardModal"
      :on-confirm="confirmRemoveCard"
      :title="$t('KANBAN.REMOVE_CARD_MODAL.TITLE')"
      :message="$t('KANBAN.REMOVE_CARD_MODAL.MESSAGE')"
      :confirm-text="$t('KANBAN.REMOVE_CARD_MODAL.CONFIRM')"
      :reject-text="$t('KANBAN.REMOVE_CARD_MODAL.CANCEL')"
    />

    <!-- Modal de edição do pipeline -->
    <woot-modal
      :show.sync="showEditPipelineModal"
      :on-close="closeEditPipelineModal"
    >
      <edit-attribute
        :selected-attribute="selectedAttribute"
        :is-updating="uiFlags.isUpdating"
        @on-close="handleEditPipelineSuccess"
        @on-cancel="closeEditPipelineModal"
      />
    </woot-modal>

    <!-- Modal de confirmação para excluir pipeline -->
    <woot-confirm-delete-modal
      v-if="showDeletePipelineModal && selectedAttribute"
      :show.sync="showDeletePipelineModal"
      title="Excluir Pipeline"
      :message="`Tem certeza que deseja excluir o pipeline ${selectedAttribute.attribute_display_name}?`"
      confirm-text="Sim, excluir"
      reject-text="Não, manter"
      :confirm-value="selectedAttribute.attribute_display_name"
      :confirm-place-holder-text="`Digite ${selectedAttribute.attribute_display_name} para confirmar`"
      @on-confirm="confirmDeletePipeline"
      @on-close="closeDeletePipelineModal"
    />

    <woot-loading-state
      v-if="uiFlags.isFetching"
      :message="$t('ATTRIBUTES_MGMT.LOADING')"
    />

    <!-- Win/Lost Modal -->
    <win-lost-modal
      :show="showWinLostModal"
      :contact="winLostModalContact"
      :status="winLostModalStatus"
      :pipeline-id="selectedAttribute ? selectedAttribute.id : null"
      :current-deal-value="winLostModalDealValue"
      @close="closeWinLostModal"
      @save="handleWinLostModalSave"
    />

    <!-- Add Contact to Stage Modal -->
    <add-contact-to-stage-modal
      v-if="showAddContactModal"
      :show="showAddContactModal"
      :selected-stage="selectedStageForContact"
      :pipeline-id="selectedAttribute ? selectedAttribute.id : null"
      :attribute-key="selectedAttribute ? selectedAttribute.attribute_key : ''"
      @close="handleCloseAddContactModal"
      @contact-added="handleContactAdded"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import draggable from 'vuedraggable';
import { formatUnixDate } from 'shared/helpers/DateHelper';
import Vue from 'vue';
import KanbanColumn from './KanbanColumn.vue';
import KanbanHeader from './Header.vue';
import EditAttribute from 'dashboard/routes/dashboard/settings/attributes/EditAttribute.vue';
import CreateAttributeModal from './CreateAttributeModal.vue';
import WinLostModal from './WinLostModal.vue';
import AddContactToStageModal from './AddContactToStageModal.vue';
import { KanbanOperationManager } from '../utils/KanbanOperationManager';
import { KanbanAttributeService } from '../utils/KanbanAttributeService';
import { PipelineCacheManager } from '../services/PipelineCacheManager';
import { KanbanLogger } from '../utils/KanbanLogger';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { getRandomColor } from 'dashboard/helper/labelColor';

// Criar um barramento de eventos local se não existir um global
const bus = new Vue();

export default {
  name: 'KanbanAttributes',
  components: {
    draggable,
    KanbanColumn,
    KanbanHeader,
    EditAttribute,
    CreateAttributeModal,
    WinLostModal,
    AddContactToStageModal,
  },
  data() {
    return {
      columns: [],
      selectedAttribute: null,
      showFilterModal: false,
      showCreateAttributeModal: false,
      showPipelineDropdown: false,
      currentView: 'kanban',
      filters: {},
      colorMap: {},
      bus: null,
      searchQuery: '',
      filteredColumns: [],
      processingUpdate: false,
      recentUpdates: new Map(),
      debugMode: false,
      lastColumnUpdateTime: 0,
      syncLock: false,
      syncOperationTimeout: null,
      operationRegistry: {},
      updateAttempts: 0,
      currentOperationId: null,
      cycleDetectionTimer: null,
      updateTimestamps: [],
      cycleDetectionActive: false,
      logger: null,
      operationManager: null,
      updateDebounceTimeout: null,
      searchDebounce: null,
      setupColumnsTimeout: null,
      showRemoveCardModal: false,
      cardToRemove: null,
      showEditPipelineModal: false,
      showDeletePipelineModal: false,
      isCreating: false,
      currentLocale: this.$i18n.locale,
      isLoadingContacts: false,
      winLostFilter: 'open', // 'all', 'won', 'lost', 'open'
      loadingProgress: null,
      loadingMessage: '',
      isLoadingInitialData: false,
      pagination: null,
      pipelineCacheManager: null,
      showWinLostModal: false,
      winLostModalContact: {},
      winLostModalStatus: 'won',
      winLostModalDealValue: 0,
      // Modal para adicionar contato na etapa
      showAddContactModal: false,
      selectedStageForContact: '',
    };
  },
  created() {
    this.initializeComponent();
  },
  mounted() {
    this.fetchAttributes();
    this.bus = this.$bus || bus;

    if (this.bus) {
      this.bus.$on(BUS_EVENTS.THEME_CHANGE, this.checkDarkMode);
      this.bus.$on(
        'contact_attribute_updated',
        this.handleContactAttributeUpdate
      );
      this.bus.$on('contact_updated', this.handleContactUpdate);
      this.bus.$on('kanban_clear_updates', this.clearUpdateCache);
    }

    this.startCycleDetection();
    this.$el.addEventListener('scroll', this.updateScrollPosition);
    document.addEventListener('click', this.handleClickOutside);

    this.$nextTick(() => {
      this.updateTranslations();
      this.migrateContactsStageTracking();
    });

    // Migrar dados para nova estrutura
    this.migrateToGroupedStructure();
  },
  beforeDestroy() {
    clearTimeout(this.updateDebounceTimeout);
    clearTimeout(this.searchDebounce);
    clearTimeout(this.setupColumnsTimeout);

    if (this.bus) {
      this.bus.$off(BUS_EVENTS.THEME_CHANGE, this.checkDarkMode);
      this.bus.$off(
        'contact_attribute_updated',
        this.handleContactAttributeUpdate
      );
      this.bus.$off('contact_updated', this.handleContactUpdate);
      this.bus.$off('kanban_clear_updates', this.clearUpdateCache);
    }

    this.operationManager.clearOperations();
    this.logger.clear();

    this.$el.removeEventListener('scroll', this.updateScrollPosition);
    document.removeEventListener('click', this.handleClickOutside);
    cancelAnimationFrame(this.requestID);
  },
  computed: {
    ...mapGetters({
      attributes: 'attributes/getAttributes',
      contacts: 'contacts/getContacts',
      uiFlags: 'attributes/getUIFlags',
    }),
    isDarkMode() {
      return this.$store.getters['theme/isDarkMode'];
    },
    listTypeAttributes() {
      // Filtrar apenas atributos marcados como Kanban
      const filteredAttrs = this.attributes.filter(attr => {
        // Se a coluna is_kanban existe, usar apenas ela para filtrar
        if (attr.hasOwnProperty('is_kanban')) {
          return attr.is_kanban === true && attr.attribute_model === 'contact_attribute';
        }
        
        // Fallback apenas para dados muito antigos (quando coluna não existe)
        // Esse fallback será removido em futuras versões
        return attr.attribute_display_type === 'list' && 
               attr.attribute_model === 'contact_attribute';
      });
      return filteredAttrs;
    },
    defaultAttribute() {
      // Se houver apenas um atributo do tipo kanban, seleciona-o automaticamente
      if (this.listTypeAttributes.length === 1) {
        return this.listTypeAttributes[0];
      }
      // Se houver mais de um, prioriza o mais recente
      if (this.listTypeAttributes.length > 1) {
        return [...this.listTypeAttributes].sort(
          (a, b) => new Date(b.created_at) - new Date(a.created_at)
        )[0];
      }
      return null;
    },
    displayColumns() {
      return this.filteredColumns.length ? this.filteredColumns : this.columns;
    },
    isAdmin() {
      // Verifica se o usuário atual é administrador
      return this.currentUser && this.currentUser.role === 'administrator';
    },

  },
  watch: {
    // Observar mudanças nos contatos para atualizar as colunas
    contacts: {
      handler() {
        if (this.selectedAttribute) {
          this.setupColumns();
        }
      },
    },
    // Observar mudanças na query de busca
    searchQuery: {
      handler(newVal) {
        if (!newVal || newVal.trim() === '') {
          this.filteredColumns = [...this.columns];
        } else {
          this.handleSearch();
        }
      },
    },
    // Observar mudanças no locale
    '$i18n.locale': {
      immediate: true,
      handler(newLocale) {
        this.currentLocale = newLocale;
        this.updateTranslations();
      },
    },
    // Observar mudanças no selectedAttribute
    selectedAttribute: {
      handler(newVal, oldVal) {
        if (newVal && newVal.id !== (oldVal ? oldVal.id : null)) {
          if (oldVal) {
            this.pipelineCacheManager.updateCache(oldVal.id, this.pagination);
          }
          this.fetchContacts();
        }
      },
    },

  },
  methods: {
    async initializeComponent() {
      await this.initializeServices();
      await this.loadInitialData();
    },
    async initializeServices() {
      this.pipelineCacheManager = new PipelineCacheManager(this.$store);
      this.logger = new KanbanLogger(false);
      this.operationManager = new KanbanOperationManager(this.logger);
      this.attributeService = new KanbanAttributeService(
        this.$store,
        this.logger
      );
    },
    async loadInitialData() {
      try {
        this.isLoadingInitialData = true; // Definir flag como true no início

        await this.fetchAttributes();
        if (this.listTypeAttributes.length > 0) {
          // Always select the first pipeline if none is selected
          if (!this.selectedAttribute) {
            this.selectedAttribute = this.listTypeAttributes[0];
          }
          await this.fetchContacts();
          this.setupColumns();
        }
      } catch (error) {
        this.safeShowNotification(
          'error',
          this.$t('KANBAN.ERRORS.LOAD_FAILED')
        );
      } finally {
        this.isLoadingInitialData = false; // Definir flag como false ao final
      }
    },
    safeShowNotification(type, message) {
      try {
        if (window.bus) {
          window.bus.$emit('show-alert', {
            type,
            message,
            show: true,
          });
        }
      } catch (error) {
        // Silenciar erro
      }
    },
    checkDarkMode() {
      // Método para atualizar o isDarkMode quando o tema mudar
    },
    async handleContactAttributeUpdate(contact, attribute, payload) {
      const attributeKey = Object.keys(attribute)[0];
      const attributeValue = attribute[attributeKey];

      // Verificar se esta atualização veio do próprio Kanban (para evitar loops)
      if (payload && payload.fromKanban) {
        this.logger.log('info', 'Ignorando atualização iniciada pelo Kanban', {
          contactId: contact.id,
          attribute: attributeKey,
          operation: payload.kanbanOperation,
        });
        return;
      }

      // Log do início da operação
      this.logger.log('info', 'Iniciando atualização de atributo', {
        contactId: contact.id,
        attribute: attributeKey,
        value: attributeValue,
      });

      // Verificar se já existe operação pendente
      if (this.operationManager.isOperationPending(contact.id)) {
        this.logger.log('warn', 'Operação pendente encontrada, aguardando...', {
          contactId: contact.id,
          attribute: attributeKey,
        });
        return;
      }

      // Verificar se o atributo é o que estamos exibindo no Kanban
      if (
        this.selectedAttribute &&
        attributeKey !== this.selectedAttribute.attribute_key
      ) {
        this.logger.log(
          'info',
          'Atributo não corresponde ao Kanban atual, ignorando',
          {
            kanbanAttr: this.selectedAttribute.attribute_key,
            updateAttr: attributeKey,
          }
        );
        return;
      }

      // Atualizar o cache em tempo real
      if (this.selectedAttribute) {
        this.updatePipelineCacheForContact(
          this.selectedAttribute.id,
          contact.id,
          attributeValue
        );
      }

      // Registrar nova operação
      const operationId = this.operationManager.registerOperation(
        contact.id,
        attributeValue
      );

      try {
        // Debounce para evitar múltiplas atualizações
        clearTimeout(this.updateDebounceTimeout);
        this.updateDebounceTimeout = setTimeout(async () => {
          await this.updateCardPosition(contact, attributeValue, operationId);
        }, 300);

        // Tracking do evento
        this.trackEvent('card_move_started', {
          contact_id: contact.id,
          from_column: this.getCurrentColumn(contact.id),
          to_column: attributeValue,
          operation_id: operationId,
        });
      } catch (error) {
        this.logger.log('error', 'Erro ao atualizar posição do card', {
          error,
          contactId: contact.id,
          operationId,
        });
        this.operationManager.completeOperation(operationId, false);

        // Tracking do erro
        this.trackEvent('card_move_error', {
          contact_id: contact.id,
          error: error.message,
          operation_id: operationId,
        });
      }
    },

    async updateCardPosition(contact, newColumn, operationId) {
      const previousColumn = this.getCurrentColumn(contact.id);

      // Atualizar UI primeiro (otimista)
      this.updateColumnsLocally(contact, newColumn);

      try {
        // Atualizar no servidor usando o Vuex store
        if (this.selectedAttribute) {
          // Preparar dados de tracking de tempo
          const now = new Date().toISOString();

          // Garantir que additional_attributes existe
          let additionalAttributes = contact.additional_attributes || {};

          // Criar uma cópia profunda para evitar referências
          additionalAttributes = JSON.parse(
            JSON.stringify(additionalAttributes)
          );

          // Garantir que a estrutura base existe
          if (!additionalAttributes.kanban) {
            additionalAttributes.kanban = {};
          }

          const pipelineId = this.selectedAttribute.id;

          // Garantir que a estrutura do pipeline existe
          if (!additionalAttributes.kanban[pipelineId]) {
            additionalAttributes.kanban[pipelineId] = {};
          }

          // Garantir que stage_tracking existe
          if (!additionalAttributes.kanban[pipelineId].stage_tracking) {
            additionalAttributes.kanban[pipelineId].stage_tracking = {};
          }

          // Atualizar o estágio atual
          const newStage = {
            stage_id: newColumn,
            entered_at: now,
          };

          // Atualizar stage_tracking
          additionalAttributes.kanban[pipelineId].stage_tracking.current =
            newStage;

          const contactParams = {
            id: contact.id,
            custom_attributes: {
              [this.selectedAttribute.attribute_key]: newColumn,
            },
            additional_attributes: additionalAttributes,
          };

          await this.$store.dispatch('contacts/update', contactParams);

          this.operationManager.completeOperation(operationId, true);

          // Forçar atualização da UI
          this.$nextTick(() => {
            this.setupColumns();
          });

          // Tracking de sucesso
          this.trackEvent('card_move_completed', {
            contact_id: contact.id,
            from_column: previousColumn,
            to_column: newColumn,
            operation_id: operationId,
          });
        }
      } catch (error) {
        // Reverter mudança local em caso de erro
        this.revertLocalUpdate(contact, previousColumn);
        this.operationManager.completeOperation(operationId, false);

        // Notificar o usuário
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('KANBAN.ERRORS.UPDATE_FAILED'),
        });
      }
    },

    getCurrentColumn(contactId) {
      return (
        this.columns.find(column =>
          column.items.some(item => item.id === contactId)
        )?.title || null
      );
    },

    updateColumnsLocally(contact, newColumn) {
      // Remover card da coluna atual
      this.columns.forEach(column => {
        const index = column.items.findIndex(item => item.id === contact.id);
        if (index !== -1) {
          column.items.splice(index, 1);
        }
      });

      // Adicionar card na nova coluna
      const targetColumn = this.columns.find(col => col.title === newColumn);
      if (targetColumn) {
        targetColumn.items.push(contact);
      }
    },

    revertLocalUpdate(contact, previousColumn) {
      this.logger.log('warn', 'Revertendo atualização local', {
        contactId: contact.id,
        previousColumn,
      });
      this.updateColumnsLocally(contact, previousColumn);
    },

    trackEvent(event, data = {}) {
      if (window.$chatwoot?.analytics) {
        window.$chatwoot.analytics.track(`kanban_${event}`, {
          ...data,
          timestamp: new Date().toISOString(),
          account_id: this.$store.getters.getCurrentAccountId,
        });
      }
    },

    hasCardError(contactId) {
      if (!this.operationManager) return false;
      const operation = Array.from(
        this.operationManager.operations.values()
      ).find(op => op.cardId === contactId);
      return operation && operation.status === 'failed';
    },

    handleSearch() {
      // Debounce para evitar sobrecarga em buscas rápidas
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(() => {
        const query = (this.searchQuery || '').toLowerCase();
        
        this.filteredColumns = this.columns.map(column => {
          const filteredItems = column.items.filter(contact => {
            // Search filter
            let matchesSearch = true;
            if (query && query.trim() !== '') {
              const name = (contact.name || '').toLowerCase();
              const email = (contact.email || '').toLowerCase();
              const phone = (contact.phone_number || '').toLowerCase();

              matchesSearch = (
                name.includes(query) ||
                email.includes(query) ||
                phone.includes(query)
              );
            }

            // Win/Lost filter
            const additionalAttributes = contact.additional_attributes || {};
            const kanban = additionalAttributes.kanban || {};
            const pipelineData = kanban[this.selectedAttribute?.id] || {};
            const winLostStatus = pipelineData.win_lost?.status;

            let matchesWinLost = true;
            if (this.winLostFilter === 'won') {
              matchesWinLost = winLostStatus === 'won';
            } else if (this.winLostFilter === 'lost') {
              matchesWinLost = winLostStatus === 'lost';
            } else if (this.winLostFilter === 'open') {
              matchesWinLost = !winLostStatus || winLostStatus === null || winLostStatus === undefined;
            }
            // 'all' shows everything

            // Debug log para verificar filtros
            if (this.debugMode) {
              console.log('Filtering contact:', {
                name: contact.name,
                winLostFilter: this.winLostFilter,
                winLostStatus,
                matchesWinLost,
                matchesSearch
              });
            }

            return matchesSearch && matchesWinLost;
          });

          return {
            ...column,
            items: filteredItems,
          };
        });

        this.logger.log('info', 'Filtros aplicados', {
          query: this.searchQuery,
          winLostFilter: this.winLostFilter,
          resultCount: this.filteredColumns.reduce(
            (sum, col) => sum + col.items.length,
            0
          ),
        });
      }, 300);
    },

    handleContactAttributeRemoved(contact, attributeKey) {
      this.logger.log('info', this.$t('KANBAN.CONTACT_ATTRIBUTE_REMOVED'));

      // Se o kanban estiver aberto e for o mesmo atributo que foi removido
      if (
        this.selectedAttribute &&
        this.selectedAttribute.attribute_key === attributeKey &&
        !this.processingUpdate // Adiciona verificação para evitar loop
      ) {
        // Atualizar colunas para remover o card
        this.setupColumns();

        // Mostrar notificação
        this.safeShowNotification(
          'info',
          this.$t('KANBAN.CONTACT_ATTRIBUTE_REMOVED')
        );
      }
    },
    handleAttributeRemovedFromKanban(contactId, attributeKey) {
      if (
        this.selectedAttribute &&
        this.selectedAttribute.attribute_key === attributeKey
      ) {
        this.setupColumns();
      }
    },
    async fetchAttributes() {
      try {
        await this.$store.dispatch('attributes/get');

        // Forçar atualização se houver atributos válidos
        if (this.listTypeAttributes.length > 0 && !this.selectedAttribute) {
          this.selectedAttribute = this.defaultAttribute;
          this.fetchContacts();
        }
      } catch (error) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('ATTRIBUTES_MGMT.API.FETCH_ERROR'),
        });
      }
    },
    async fetchContacts() {
      if (!this.selectedAttribute) return;

      try {
        this.isLoadingContacts = true;
        this.pagination = {
          currentPage: 0,
          totalPages: 0,
          hasMore: true,
          isLoadingMore: false,
        };

        // Limpar contatos existentes ao carregar do início
        this.$store.commit('contacts/CLEAR_CONTACTS');

        // Carregar todos os contatos
        await this.loadAllContacts();

        // Configurar as colunas apenas depois que todos os contatos forem carregados
        this.setupColumns();
      } catch (error) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('KANBAN.ERRORS.LOAD_FAILED'),
        });
      } finally {
        this.isLoadingContacts = false;
      }
    },

    async loadAllContacts() {
      try {
        this.pagination.isLoadingMore = true;
        let currentPage = 1;
        let totalContactsLoaded = 0;
        const existingContacts = [];

        // Preparar o payload para a API de filtro
        const queryPayload = {
          payload: [
            {
              attribute_key: this.selectedAttribute.attribute_key,
              filter_operator: 'is_present',
              values: [],
              query_operator: 'AND',
            },
          ],
        };

        // Adicionar busca se houver
        if (this.searchQuery) {
          queryPayload.payload.push({
            attribute_key: 'name',
            filter_operator: 'contains',
            values: [this.searchQuery],
            query_operator: 'OR',
          });
          queryPayload.payload.push({
            attribute_key: 'email',
            filter_operator: 'contains',
            values: [this.searchQuery],
            query_operator: 'OR',
          });
          queryPayload.payload.push({
            attribute_key: 'phone_number',
            filter_operator: 'contains',
            values: [this.searchQuery],
            query_operator: 'OR',
          });
        }

        // Função para carregar uma página de contatos
        const loadContactsPage = async page => {
          try {
            const contacts = await this.$store.dispatch('contacts/filter', {
              page,
              queryPayload,
              resetState: false,
            });
            return contacts || [];
          } catch (error) {
            return [];
          }
        };

        // Função recursiva para carregar páginas sem usar await em loop
        const loadNextPage = async page => {
          const contacts = await loadContactsPage(page);

          // Se não há contatos, terminamos
          if (!contacts || contacts.length === 0) {
            return {
              lastPage: page - 1,
              hasMore: false,
            };
          }

          // Filtrar contatos duplicados
          const newContacts = contacts.filter(
            contact =>
              !existingContacts.some(existing => existing.id === contact.id)
          );

          // Adicionar novos contatos
          if (newContacts.length > 0) {
            existingContacts.push(...newContacts);
            this.$store.commit('contacts/SET_CONTACTS', existingContacts);
            totalContactsLoaded += newContacts.length;
          }

          // Se recebemos menos contatos que o tamanho da página (15), terminamos
          if (contacts.length < 15) {
            return {
              lastPage: page,
              hasMore: false,
            };
          }

          // Carregar próxima página
          return loadNextPage(page + 1);
        };

        // Iniciar o carregamento recursivo
        const result = await loadNextPage(currentPage);

        // Atualizar o cache do pipeline
        this.pipelineCacheManager.updateCache(this.selectedAttribute.id, {
          currentPage: result.lastPage,
          totalPages: Math.ceil(totalContactsLoaded / 15),
          hasMore: result.hasMore,
          isLoadingMore: false,
        });
      } catch (error) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('KANBAN.ERRORS.LOAD_MORE_FAILED'),
        });
      } finally {
        this.pagination.isLoadingMore = false;
      }
    },
    selectAttribute(attribute) {
      this.selectedAttribute = attribute;
    },
    setupColumns() {
      if (!this.selectedAttribute || !this.selectedAttribute.attribute_values) {
        return;
      }

      // Registrar timestamp para detecção de ciclos (apenas se não está em reset)
      if (!this.cycleDetectionActive) {
        const now = Date.now();
        this.updateTimestamps.push(now);
      }

      // Controlar a taxa de atualizações
      const now = Date.now();
      if (now - this.lastColumnUpdateTime < 1500) {
        // Aumentado para 1.5 segundos

        // Usar o operationManager para registrar essa operação adiada
        if (this.operationManager) {
          this.operationManager.registerOperation('setup-columns', 'throttled');
        }

        // Cancelar qualquer atualização pendente
        clearTimeout(this.setupColumnsTimeout);

        // Agendar apenas uma atualização futura
        this.setupColumnsTimeout = setTimeout(() => {
          // Verificar novamente se podemos atualizar
          if (!this.processingUpdate && !this.syncLock) {
            this.setupColumns();
          }
        }, 1800);

        return;
      }
      this.lastColumnUpdateTime = now;

      // Logging para monitoramento
      this.logger.log('info', 'Reconstruindo colunas', {
        attribute: this.selectedAttribute.attribute_display_name,
        timestamp: now,
      });

      this.columns = [];
      const values = this.selectedAttribute.attribute_values;

      // Criar colunas a partir dos valores de atributos
      values.forEach((value, index) => {
        // Usar uma cor consistente para cada valor
        const color = this.getStageColor(value);
        const contacts = this.getContactsForColumn(value);

        this.columns.push({
          id: `column-${index}`,
          title: value,
          color: color,
          items: contacts,
        });
      });

      // Debug log para mostrar o conteúdo de cada coluna
      this.logColumnsContent();

      // Aplicar filtros após criar colunas
      this.$nextTick(() => {
        this.handleSearch();
        
        // Garantir que a UI seja atualizada imediatamente
        this.$forceUpdate();

        // Adicionar uma pequena animação de fade-in para melhorar a experiência do usuário
        if (this.$el && this.$el.querySelector('.kanban-columns')) {
          const columns = this.$el.querySelector('.kanban-columns');
          columns.style.opacity = '0';
          columns.style.transition = 'opacity 0.3s ease-in-out';

          setTimeout(() => {
            columns.style.opacity = '1';
          }, 100);
        }
      });
    },
    getContactsForColumn(columnValue) {
      if (!this.selectedAttribute) return [];

      const attrKey = this.selectedAttribute.attribute_key;

      return this.contacts.filter(contact => {
        if (!contact.custom_attributes) {
          return false;
        }

        // Garantir que cada contato tenha propriedades básicas
        if (!contact.labels) {
          contact.labels = [];
        }

        if (!contact.additional_attributes) {
          contact.additional_attributes = {};
        }

        // Procura pelo valor exato no atributo personalizado
        const attributeValue = contact.custom_attributes[attrKey];
        const matches = attributeValue === columnValue;

        return matches;
      });
    },
    async onItemMoved({ contactId, sourceColumnTitle, targetColumnTitle }) {
      // Verificar se o contato existe
      const contact = this.contacts.find(c => c.id === contactId);
      if (!contact) return;

      try {
        const now = new Date().toISOString();
        let additionalAttributes = contact.additional_attributes || {};

        // Criar uma cópia profunda para evitar referências
        additionalAttributes = JSON.parse(JSON.stringify(additionalAttributes));

        // Garantir que a estrutura base existe
        if (!additionalAttributes.kanban) {
          additionalAttributes.kanban = {};
        }

        if (!additionalAttributes.kanban[this.selectedAttribute.id]) {
          additionalAttributes.kanban[this.selectedAttribute.id] = {};
        }

        // Garantir que stage_tracking existe
        if (
          !additionalAttributes.kanban[this.selectedAttribute.id].stage_tracking
        ) {
          additionalAttributes.kanban[
            this.selectedAttribute.id
          ].stage_tracking = {};
        }

        // Atualizar o estágio atual
        additionalAttributes.kanban[
          this.selectedAttribute.id
        ].stage_tracking.current = {
          stage_id: targetColumnTitle,
          entered_at: now,
        };

        // Preparar os dados para atualização
        const contactParams = {
          id: contactId,
          custom_attributes: {
            [this.selectedAttribute.attribute_key]: targetColumnTitle,
          },
          additional_attributes: additionalAttributes,
        };

        // Atualizar o contato
        await this.$store.dispatch('contacts/update', contactParams);
      } catch (error) {
        // Reverter a mudança local em caso de erro
        this.revertLocalUpdate(contact, sourceColumnTitle);

        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('KANBAN.ERRORS.UPDATE_FAILED'),
        });
      }
    },
    openContact(contactId) {
      // Abre a página de detalhes do contato
      this.$router.push(
        frontendURL(
          `accounts/${this.$route.params.accountId}/contacts/${contactId}`
        )
      );
    },

    closeFilterModal() {
      this.showFilterModal = false;
    },
    applyFilters() {
      // Aplicar filtros e atualizar visualização
      this.fetchContacts();
      this.closeFilterModal();
    },
    getLabelColor(label) {
      // Gera uma cor para o rótulo, armazenando em cache para consistência
      if (!this.colorMap[label]) {
        this.colorMap[label] = getRandomColor(
          Object.keys(this.colorMap).length
        );
      }
      return this.colorMap[label];
    },
    getLastActivityTime(contact) {
      if (!contact.last_activity_at) return '';
      return formatUnixDate(contact.last_activity_at);
    },
    openCreateAttributeModal() {
      this.showCreateAttributeModal = true;
    },

    async handleAttributeCreated(attributeData) {
      this.showCreateAttributeModal = false;
      await this.fetchAttributes();
      
      // Selecionar o atributo recém-criado
      const newAttribute = this.listTypeAttributes.find(
        attr => attr.attribute_key === attributeData.attribute_key
      );
      if (newAttribute) {
        this.selectedAttribute = newAttribute;
        await this.fetchContacts();
        this.setupColumns();
      }
      
      this.safeShowNotification(
        'success',
        this.$t('KANBAN.SUCCESS.ATTRIBUTE_CREATED')
      );
    },

    handleCreateError(error) {
      this.safeShowNotification(
        'error',
        error?.message || this.$t('KANBAN.ERRORS.CREATE_FAILED')
      );
    },

    // Método para garantir a mesma cor para o mesmo estágio sempre
    getStageColor(stageName) {
      if (!this.colorMap[stageName]) {
        // Cores predefinidas para estágios comuns
        const stageColors = {
          'novo lead': '#36B37E', // Verde
          'em contato': '#00B8D9', // Azul claro
          qualificado: '#6554C0', // Roxo
          'proposta enviada': '#FFAB00', // Laranja
          negociação: '#FF8B00', // Laranja escuro
          'fechado ganho': '#36B37E', // Verde
          'fechado perdido': '#FF5630', // Vermelho
          'em andamento': '#00C7E6', // Azul cyan
          aguardando: '#6B778C', // Cinza
          suspenso: '#aaaaaa', // Cinza claro
          cancelado: '#FF5630', // Vermelho
          finalizado: '#36B37E', // Verde
        };

        // Verificar se existe uma cor predefinida para este estágio (case-insensitive)
        const stageNameLower = stageName.toLowerCase();
        const stageEntries = Object.entries(stageColors);

        // Usando método de array em vez de loop for...of
        const matchingStage = stageEntries.find(
          ([key]) =>
            stageNameLower.includes(key) || key.includes(stageNameLower)
        );

        if (matchingStage) {
          this.colorMap[stageName] = matchingStage[1]; // Atribuir a cor
        } else {
          // Se não encontrou uma cor predefinida, gerar uma cor consistente
          // Gerar cor baseada na string para ser consistente
          this.colorMap[stageName] = getRandomColor(
            stageName
              .split('')
              .reduce((acc, char) => acc + char.charCodeAt(0), 0)
          );
        }
      }

      return this.colorMap[stageName];
    },
    // Adicione um método para remover um cartão explicitamente do Kanban
    removeCardFromKanban(contactId) {
      // Armazenar ID do contato e mostrar modal de confirmação
      this.cardToRemove = contactId;
      this.showRemoveCardModal = true;
    },

    // Métodos para controlar o modal de confirmação
    closeRemoveCardModal() {
      this.showRemoveCardModal = false;
      this.cardToRemove = null;
    },

    // Confirmar a remoção do card após confirmação do usuário
    async confirmRemoveCard() {
      if (!this.cardToRemove || !this.selectedAttribute) return;

      try {
        // Get the contact object from the columns
        const contact = this.columns.reduce((found, column) => {
          if (found) return found;
          return column.items.find(item => item.id === this.cardToRemove);
        }, null);

        if (!contact) {
          return;
        }

        // Update the contact
        await this.$store.dispatch('contacts/update', {
          id: contact.id,
          custom_attributes: {
            [this.selectedAttribute.attribute_key]: null,
          },
        });

        // Update local state
        this.setupColumns();

        // Show success message
        if (window.bus) {
          window.bus.$emit('show-alert', {
            message: this.$t('KANBAN.CARD_REMOVED_SUCCESS'),
            type: 'success',
          });
        }

        // Close the modal
        this.closeRemoveCardModal();
      } catch (error) {
        if (window.bus) {
          window.bus.$emit('show-alert', {
            message: this.$t('KANBAN.ERRORS.REMOVE_FAILED'),
            type: 'error',
          });
        }
      }
    },
    toggleDebugMode() {
      this.debugMode = !this.debugMode;
    },
    // Método adicional para tratar eventos de atualização completa de contato
    handleContactUpdate(payload) {
      // Ignorar atualizações que vieram do Kanban para evitar loops

      if (payload.fromKanban || payload.kanbanOperation) {
        this.logger.log('info', 'Ignorando atualização iniciada pelo Kanban', {
          contactId: payload.id,
          operation: payload.kanbanOperation,
        });
        return;
      }

      // Se não há atributo selecionado, não há o que atualizar
      if (!this.selectedAttribute) {
        return;
      }

      // Extrair o atributo relevante
      const { attribute_key: attributeKey } = this.selectedAttribute;
      const attributeValue = this.getAttributeValue(
        payload.custom_attributes,
        attributeKey
      );

      if (!attributeValue) {
        return;
      }

      // Verificar se o card já está na coluna correta
      const contact = this.contacts.find(c => c.id === payload.id);
      if (!contact) {
        return;
      }

      // Encontrar a coluna atual do contato
      const currentColumn = this.getCurrentColumn(payload.id);

      // Se o card já está na coluna correta, não precisa atualizar
      if (currentColumn === attributeValue) {
        return;
      }

      // Atualizar localmente sem disparar novos eventos
      this.logger.log(
        'info',
        'Atualizando posição do card localmente após alteração externa',
        {
          contactId: payload.id,
          from: currentColumn,
          to: attributeValue,
        }
      );

      // Aguardar um pouco para evitar concorrência com outras atualizações
      setTimeout(() => {
        this.updateColumnsLocally(contact, attributeValue);
      }, 300);
    },
    // Helper para lidar com valores de atributos potencialmente ausentes
    getAttributeValue(customAttributes, attributeKey) {
      if (!customAttributes) {
        return null;
      }
      return customAttributes[attributeKey] || null;
    },
    // Versão simplificada da trava de sincronização
    activateSyncLock() {
      this.syncLock = true;
      this.logger.log('info', 'Trava de sincronização ativada');

      // Timeout de segurança para liberar após 15 segundos
      this.syncOperationTimeout = setTimeout(() => {
        this.syncLock = false;
        this.logger.log(
          'warn',
          'Trava de sincronização liberada por timeout de segurança'
        );
      }, 15000);
    },
    // Versão simplificada da liberação de trava
    releaseSyncLock() {
      clearTimeout(this.syncOperationTimeout);
      this.syncLock = false;
      this.logger.log('info', 'Trava de sincronização liberada');
    },
    // Método para redefinir todas as travas
    resetAllLocks() {
      // Limpar todos os flags de controle
      this.processingUpdate = false;
      this.syncLock = false;
      this.currentOperationId = null;

      // Limpar operações em andamento
      this.operationRegistry = {};

      // Limpar todos os timeouts
      clearTimeout(this.syncOperationTimeout);
      clearTimeout(this.updateDebounceTimeout);
      clearTimeout(this.searchDebounce);
      clearTimeout(this.setupColumnsTimeout);

      // Resetar sistema de detecção de ciclos
      this.updateTimestamps = [];
      this.cycleDetectionActive = false;

      // Limpar todas as operações no gerenciador
      if (this.operationManager) {
        this.operationManager.clearOperations();
      }

      // Limpar serviço de atributos
      if (this.attributeService) {
        this.attributeService.clearAllLocks();
        this.attributeService.clearRecentUpdates();
      }

      this.logger.log('warn', 'Todas as travas foram redefinidas');
    },
    setupColumnsWithLock() {
      const now = Date.now();
      if (now - this.lastColumnUpdateTime < 1500) {
        setTimeout(() => {
          if (!this.processingUpdate && !this.syncLock) {
            this.setupColumns();
          }
        }, 1800);
        return;
      }

      this.lastColumnUpdateTime = now;
      this.setupColumns();
    },
    // Método para debugging das colunas
    logColumnsContent() {
      // Método mantido vazio para compatibilidade, mas sem logs
    },
    // Adicionar este novo método para limpar o cache de atualizações
    clearUpdateCache() {
      this.recentUpdates.clear();
      this.processingUpdate = false;
      this.releaseSyncLock();
    },
    startCycleDetection() {
      this.stopCycleDetection();

      this.cycleDetectionTimer = setInterval(() => {
        try {
          const now = Date.now();
          const tenSecondsAgo = now - 10000;
          this.updateTimestamps = this.updateTimestamps.filter(
            timestamp => timestamp > tenSecondsAgo
          );

          if (this.updateTimestamps.length > 20) {
            if (!this.cycleDetectionActive) {
              this.cycleDetectionActive = true;
              this.stopCycleDetection();
              this.resetAllLocks();

              this.safeShowNotification(
                'warning',
                this.$t('KANBAN.ERRORS.TOO_MANY_UPDATES')
              );

              setTimeout(() => {
                this.cycleDetectionActive = false;
                setTimeout(() => {
                  if (!this.cycleDetectionTimer) {
                    this.startCycleDetection();
                  }
                }, 3000);
              }, 8000);
            }
          }
        } catch (error) {
          this.stopCycleDetection();
        }
      }, 2000);
    },
    stopCycleDetection() {
      if (this.cycleDetectionTimer) {
        clearInterval(this.cycleDetectionTimer);
        this.cycleDetectionTimer = null;
      }
    },
    handleColumnItemsUpdate({ columnId, items }) {
      const columnIndex = this.columns.findIndex(col => col.id === columnId);
      if (columnIndex !== -1) {
        this.columns[columnIndex].items = items;
      }
    },
    openConversation(conversationId) {
      const conversationUrl = frontendURL(
        `accounts/${this.$route.params.accountId}/conversations/${conversationId}`
      );
      window.open(conversationUrl, '_blank');
    },
    togglePipelineDropdown() {
      this.showPipelineDropdown = !this.showPipelineDropdown;
    },
    selectPipeline(pipeline) {
      this.selectedAttribute = pipeline;
      this.showPipelineDropdown = false;
      this.fetchContacts();
    },
    handleClickOutside(event) {
      const pipelineSelector = this.$el.querySelector('.pipeline-selector');
      if (pipelineSelector && !pipelineSelector.contains(event.target)) {
        this.showPipelineDropdown = false;
      }
    },
    closeEditPipelineModal() {
      this.showEditPipelineModal = false;
    },
    async handleEditPipelineSuccess() {
      this.showEditPipelineModal = false;
      
      // Recarregar dados após edição para refletir mudanças na ordem dos estágios
      await this.fetchAttributes();
      if (this.selectedAttribute) {
        // Atualizar selectedAttribute com os dados mais recentes
        const updatedAttribute = this.listTypeAttributes.find(
          attr => attr.id === this.selectedAttribute.id
        );
        if (updatedAttribute) {
          this.selectedAttribute = updatedAttribute;
          await this.fetchContacts();
          this.setupColumns();
        }
      }
    },
    async confirmDeletePipeline() {
      try {
        const contactsUsingPipeline = this.contacts.filter(contact => {
          const customAttributes = contact.custom_attributes || {};
          const attributeValue =
            customAttributes[this.selectedAttribute.attribute_key];
          return (
            attributeValue !== undefined &&
            attributeValue !== null &&
            attributeValue !== ''
          );
        });

        if (contactsUsingPipeline.length > 0) {
          this.showDeletePipelineModal = false;
          this.safeShowNotification(
            'error',
            this.$t('KANBAN.ERRORS.PIPELINE_IN_USE')
          );
          return;
        }

        await this.$store.dispatch(
          'attributes/delete',
          this.selectedAttribute.id
        );
        this.selectedAttribute = null;
        await this.fetchAttributes();

        this.safeShowNotification(
          'success',
          this.$t('KANBAN.SUCCESS.PIPELINE_DELETED')
        );

        this.showDeletePipelineModal = false;
      } catch (error) {
        this.showDeletePipelineModal = false;
        this.safeShowNotification(
          'error',
          error?.message || this.$t('KANBAN.ERRORS.DELETE_FAILED')
        );
      }
    },
    closeDeletePipelineModal() {
      this.showDeletePipelineModal = false;
    },
    editKanban() {
      if (!this.selectedAttribute) {
        this.safeShowNotification(
          'error',
          this.$t('KANBAN.ERRORS.NO_PIPELINE_SELECTED')
        );
        return;
      }
      this.showEditPipelineModal = true;
    },
    deleteKanban() {
      if (!this.selectedAttribute) {
        this.safeShowNotification(
          'error',
          this.$t('KANBAN.ERRORS.NO_PIPELINE_SELECTED')
        );
        return;
      }
      this.showDeletePipelineModal = true;
    },
    updateTranslations() {
      this.$forceUpdate();
      if (this.$refs.kanbanHeader) {
        this.$refs.kanbanHeader.$forceUpdate();
      }
    },
    async handleDrop({ removedIndex, addedIndex, payload }, columnId) {
      if (removedIndex === null && addedIndex === null) return;

      const contact = payload;
      const targetColumn = this.columns.find(col => col.id === columnId);
      if (!targetColumn) return;

      const operationId = `move-${contact.id}-${Date.now()}`;
      const oldValue =
        contact.custom_attributes[this.selectedAttribute.attribute_key];
      const newValue = targetColumn.value;

      try {
        this.operationManager.startOperation(operationId);

        // Atualizar o cache antes da chamada à API (otimista)
        this.pipelineCacheManager.updateContactInCache(
          this.selectedAttribute.id,
          contact.id,
          this.selectedAttribute.attribute_key,
          newValue
        );

        await this.updateContactAttribute(contact, newValue);
        this.operationManager.completeOperation(operationId);

        // Atualizar o cache novamente após sucesso da API
        this.pipelineCacheManager.updateCache(
          this.selectedAttribute.id,
          this.pagination
        );
      } catch (error) {
        // Reverter o cache em caso de erro
        this.pipelineCacheManager.updateContactInCache(
          this.selectedAttribute.id,
          contact.id,
          oldValue
        );

        this.operationManager.failOperation(operationId);
        this.safeShowNotification(
          'error',
          this.$t('KANBAN.ERRORS.MOVE_FAILED')
        );
      }
    },
    async updateContactAttribute(contact, newValue) {
      const customAttributes = {
        ...contact.custom_attributes,
        [this.selectedAttribute.attribute_key]: newValue,
      };

      await this.$store.dispatch('contacts/update', {
        id: contact.id,
        custom_attributes: customAttributes,
      });
    },
    updatePipelineCache(pipelineId) {
      if (!pipelineId || !this.pagination) return;

      this.pipelineCache[pipelineId] = {
        contacts: this.$store.getters['contacts/getContacts'],
        meta: this.$store.getters['contacts/getMeta'],
        pagination: { ...this.pagination },
        lastUpdated: Date.now(),
      };
    },
    updatePipelineCacheForContact(pipelineId, contactId, newColumnValue) {
      if (!pipelineId || !this.pipelineCache[pipelineId]) return;

      const cachedData = this.pipelineCache[pipelineId];
      const contacts = [...cachedData.contacts];
      const contactIndex = contacts.findIndex(c => c.id === contactId);

      if (contactIndex !== -1) {
        contacts[contactIndex] = {
          ...contacts[contactIndex],
          custom_attributes: {
            ...contacts[contactIndex].custom_attributes,
            [this.selectedAttribute.attribute_key]: newColumnValue,
          },
        };

        this.pipelineCache[pipelineId] = {
          ...cachedData,
          contacts,
          lastUpdated: Date.now(),
        };

        // Forçar atualização do store para refletir a mudança imediatamente
        this.$store.commit('contacts/SET_CONTACTS', contacts);
      }
    },
    async handleDealValueUpdate({ contactId, additionalAttributes }) {
      try {
        // Atualizar o cache local otimisticamente
        this.pipelineCacheManager.updateContactInCache(contactId, {
          additional_attributes: additionalAttributes,
        });

        // Atualizar no servidor
        await this.$store.dispatch('contacts/update', {
          id: contactId,
          additional_attributes: additionalAttributes,
        });

        // Emitir evento de sucesso se necessário
        this.safeShowNotification(
          'success',
          this.$t('CONTACTS.SUCCESS_UPDATE_CONTACT')
        );
      } catch (error) {
        // Reverter a atualização do cache em caso de erro
        this.pipelineCacheManager.revertContactUpdate(contactId);

        this.safeShowNotification(
          'error',
          error?.message || this.$t('CONTACTS.ERROR_UPDATE_CONTACT')
        );
      }
    },
    async handleWinLostUpdate({ contactId, additionalAttributes, winLostData }) {
      try {
        // Register operation for loading state
        const operationId = this.operationManager?.registerOperation(contactId, 'win_lost_update');

        // Update the cache optimistically
        this.pipelineCacheManager.updateContactInCache(
          this.selectedAttribute.id,
          contactId,
          'additional_attributes',
          additionalAttributes
        );

        // Update on the server
        await this.$store.dispatch('contacts/update', {
          id: contactId,
          additional_attributes: additionalAttributes,
        });

        // Mark operation as completed
        if (operationId) {
          this.operationManager?.completeOperation(operationId);
        }

        // Show success notification
        const statusText = winLostData.status === 'won' ? 'won' : 'lost';
        this.safeShowNotification(
          'success',
          `Contact marked as ${statusText}!`
        );
      } catch (error) {
        // Mark operation as failed
        if (operationId) {
          this.operationManager?.failOperation(operationId, error);
        }

        // Revert the cache update in case of error
        this.pipelineCacheManager.revertContactUpdate(this.selectedAttribute.id);

        this.safeShowNotification(
          'error',
          error?.message || 'Failed to update contact status'
        );
      }
    },
    handleWinLostFilter(filter) {
      this.winLostFilter = filter;
      // Forçar re-filtragem imediata
      this.$nextTick(() => {
        this.handleSearch(this.searchQuery || '');
      });
    },
    migrateToGroupedStructure() {
      // Verificar se há contatos que precisam de migração
      if (!this.contacts || !this.contacts.length) return;

      const contactsToMigrate = this.contacts.filter(contact => {
        const additionalAttributes = contact.additional_attributes || {};
        // Verificar se existe a estrutura antiga deal_values
        return additionalAttributes.deal_values && !additionalAttributes.kanban;
      });

      if (contactsToMigrate.length === 0) return;

      this.logger.log('info', 'Iniciando migração de estrutura', {
        contactCount: contactsToMigrate.length,
      });

      // Migrar cada contato
      contactsToMigrate.forEach(async contact => {
        try {
          const additionalAttributes = contact.additional_attributes || {};
          const dealValues = additionalAttributes.deal_values || {};

          // Criar nova estrutura
          const kanban = {};

          // Para cada pipeline id em deal_values
          Object.keys(dealValues).forEach(pipelineId => {
            const value = dealValues[pipelineId];

            kanban[pipelineId] = {
              deal: {
                value,
              },
              stage_tracking: {
                current: {
                  stage_id:
                    contact.custom_attributes?.[
                      this.getAttributeKeyById(pipelineId)
                    ],
                  entered_at: new Date().toISOString(),
                },
              },
            };
          });

          // Atualizar contato com nova estrutura
          const updatedAdditionalAttributes = {
            ...additionalAttributes,
            kanban,
          };

          // Remover estrutura antiga
          delete updatedAdditionalAttributes.deal_values;

          await this.$store.dispatch('contacts/update', {
            id: contact.id,
            additional_attributes: updatedAdditionalAttributes,
          });

          this.logger.log('info', 'Contato migrado com sucesso', {
            contactId: contact.id,
          });
        } catch (error) {
          this.logger.log('error', 'Erro ao migrar contato', {
            contactId: contact.id,
            error,
          });
        }
      });
    },

    getAttributeKeyById(attributeId) {
      if (!this.attributes || !this.attributes.length) return null;

      const attribute = this.attributes.find(
        attr => attr.id === parseInt(attributeId, 10)
      );
      return attribute ? attribute.attribute_key : null;
    },
    async migrateContactsStageTracking() {
      if (!this.selectedAttribute || !this.contacts) return;

      const contactsToMigrate = this.contacts.filter(contact => {
        const additionalAttributes = contact.additional_attributes || {};
        const kanban = additionalAttributes.kanban || {};
        const pipelineData = kanban[this.selectedAttribute.id];

        return !pipelineData?.stage_tracking?.current;
      });

      // Migrar contatos em paralelo
      const migrateContact = async contact => {
        try {
          const now = new Date().toISOString();
          const currentStage =
            contact.custom_attributes[this.selectedAttribute.attribute_key];

          let additionalAttributes = contact.additional_attributes || {};
          additionalAttributes = JSON.parse(
            JSON.stringify(additionalAttributes)
          );

          if (!additionalAttributes.kanban) {
            additionalAttributes.kanban = {};
          }

          if (!additionalAttributes.kanban[this.selectedAttribute.id]) {
            additionalAttributes.kanban[this.selectedAttribute.id] = {};
          }

          additionalAttributes.kanban[
            this.selectedAttribute.id
          ].stage_tracking = {
            current: {
              stage_id: currentStage || this.columns[0]?.title,
              entered_at: now,
            },
          };

          await this.$store.dispatch('contacts/update', {
            id: contact.id,
            additional_attributes: additionalAttributes,
          });
        } catch (error) {
          // Tratar erro silenciosamente para não interromper o processo
        }
      };

      // Executar migrações em paralelo
      await Promise.all(contactsToMigrate.map(migrateContact));
    },
    handleKanbanOperation(contact, newColumnValue, operation) {
      const operationId = `${operation}-${contact.id}-${Date.now()}`;
      const oldValue =
        contact.custom_attributes[this.selectedAttribute.attribute_key];

      // Registrar a operação
      this.operationManager.registerOperation({
        id: operationId,
        cardId: contact.id,
        type: operation,
        fromColumn: oldValue,
        toColumn: newColumnValue,
        timestamp: Date.now(),
      });

      return operationId;
    },
    handleOpenWinModal(data) {
      this.winLostModalContact = data.contact;
      this.winLostModalStatus = 'won';
      this.winLostModalDealValue = data.currentDealValue || 0;
      this.showWinLostModal = true;
    },
    handleOpenLostModal(data) {
      this.winLostModalContact = data.contact;
      this.winLostModalStatus = 'lost';
      this.winLostModalDealValue = data.currentDealValue || 0;
      this.showWinLostModal = true;
    },
    handleAddContactToStage(data) {
      this.selectedStageForContact = data.stage;
      this.showAddContactModal = true;
    },
    handleCloseAddContactModal() {
      this.showAddContactModal = false;
      this.selectedStageForContact = '';
    },
    async handleContactAdded(data) {
      // Refresh da lista de contatos para mostrar o contato adicionado
      try {
        await this.fetchContacts();
        this.setupColumns();
        useAlert(this.$t('KANBAN.ADD_CONTACT.SUCCESS', { stage: data.stage }));
      } catch (error) {

      }
    },
    closeWinLostModal() {
      this.showWinLostModal = false;
      this.winLostModalContact = {};
      this.winLostModalStatus = 'won';
      this.winLostModalDealValue = 0;
    },
    async handleWinLostModalSave(data) {
      try {
        // Usar winLostModalContact que já está disponível
        const contact = this.winLostModalContact;
        
        // Criar estrutura de additional_attributes atualizada
        const additionalAttributes = {
          ...contact.additional_attributes,
          kanban: {
            ...(contact.additional_attributes?.kanban || {}),
            [data.pipelineId]: {
              ...(contact.additional_attributes?.kanban?.[data.pipelineId] || {}),
              win_lost: data.winLostData,
              deal: {
                ...(contact.additional_attributes?.kanban?.[data.pipelineId]?.deal || {}),
                value: data.dealValue
              }
            }
          }
        };

        // Chamar o método existente de atualização
        await this.handleWinLostUpdate({
          contactId: data.contactId,
          additionalAttributes,
          winLostData: data.winLostData
        });

        // Fechar o modal
        this.closeWinLostModal();
      } catch (error) {
        this.safeShowNotification(
          'error',
          error?.message || 'Failed to update contact status'
        );
      }
    },
    async handleUndoWinLost({ contactId, additionalAttributes }) {
      try {
        // Register operation for loading state
        const operationId = this.operationManager?.registerOperation(contactId, 'undo_win_lost');

        // Update the cache optimistically
        this.pipelineCacheManager.updateContactInCache(
          this.selectedAttribute.id,
          contactId,
          'additional_attributes',
          additionalAttributes
        );

        // Update on the server
        await this.$store.dispatch('contacts/update', {
          id: contactId,
          additional_attributes: additionalAttributes,
        });

        // Mark operation as completed
        if (operationId) {
          this.operationManager?.completeOperation(operationId);
        }

        // Show success notification
        this.safeShowNotification(
          'success',
          'Contact status has been reset successfully'
        );
      } catch (error) {
        // Mark operation as failed
        if (operationId) {
          this.operationManager?.failOperation(operationId, error);
        }

        // Revert the cache update in case of error
        this.pipelineCacheManager.revertContactUpdate(this.selectedAttribute.id);

        this.safeShowNotification(
          'error',
          error?.message || 'Failed to reset contact status'
        );
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.kanban-container {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background-color: var(--s-25);
  color: var(--s-900);

  &.dark-mode {
    background-color: var(--b-800);
    color: var(--s-100);
  }
}

.kanban-select-attribute {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex: 1;

  .select-attribute-content {
    max-width: 600px;
    text-align: center;

    .empty-state-icon {
      margin-bottom: var(--space-large);
      color: var(--s-400);
      
      .dark-mode & {
        color: var(--s-500);
      }
    }

    h2 {
      font-size: var(--font-size-big);
      margin-bottom: var(--space-normal);
      font-weight: 600;
      color: var(--s-800);
      
      .dark-mode & {
        color: var(--s-200);
      }
    }

    p {
      margin-bottom: var(--space-large);
      color: var(--s-700);
      font-size: var(--font-size-normal);
      line-height: 1.6;

      .dark-mode & {
        color: var(--s-300);
      }
    }

    .action-buttons {
      display: flex;
      justify-content: center;
      margin-bottom: var(--space-large);
      
      .woot-button {
        min-width: 12rem; /* 192px - largura mínima para botões */
      }
    }
  }

  .attribute-list {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-medium);
    justify-content: center;
    margin-top: var(--space-medium);
  }

  .attribute-button {
    min-width: 180px;
    transition: transform 0.2s;

    &:hover {
      transform: translateY(-2px);
    }
  }

  .empty-state {
    margin-top: var(--space-large);
    text-align: center;

    p {
      margin-bottom: var(--space-small);
    }
  }
}

.kanban-board {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  margin-top: var(--space-small);
  transition: opacity 0.2s ease-in-out;
  animation: fadeIn 0.3s ease-in-out;
  @apply bg-white dark:bg-slate-800;
}

.kanban-columns-container {
  flex: 1;
  overflow-x: auto;
  padding: var(--space-small);
  @apply bg-slate-50 dark:bg-slate-900;
}

.kanban-columns {
  display: inline-flex;
  gap: var(--space-normal);
  padding: var(--space-small);
  min-height: 100%;
}

.filter-modal {
  width: 100%;
  max-width: 600px;
}

.filter-content {
  padding: var(--space-normal);
  min-height: 200px;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  padding: var(--space-normal);
  gap: var(--space-small);
  border-top: 1px solid var(--s-100);

  .dark-mode & {
    border-top: 1px solid var(--b-500);
  }
}

.attribute-modal {
  width: 100%;
  max-width: 500px;
}

.attribute-form {
  padding: var(--space-normal);
}

.attribute-input {
  margin-bottom: var(--space-normal);
}

.pipeline-dropdown {
  position: absolute;
  top: 4rem;
  left: 12rem;
  min-width: 200px;
  background: var(--white);
  border-radius: var(--border-radius-normal);
  box-shadow: var(--shadow-medium);
  z-index: 50;
  border: 1px solid var(--s-100);

  .dark-mode & {
    background: var(--b-700);
    border-color: var(--b-600);
  }

  .pipeline-option {
    padding: var(--space-small) var(--space-normal);
    cursor: pointer;
    transition: all 0.2s ease;

    &:hover {
      background: var(--s-50);
      .dark-mode & {
        background: var(--b-600);
      }
    }
  }
}

.attribute-modal {
  .attribute-form {
    padding: var(--space-normal);
  }

  ::v-deep {
    .multiselect {
      margin-bottom: var(--space-normal);
      position: relative;
    }

    .multiselect__tags {
      min-height: 38px;
      padding: 8px 40px 0 8px;
      border: 1px solid var(--s-200);
      border-radius: var(--border-radius-normal);
      background: var(--white);
    }

    .multiselect__tag {
      position: relative;
      display: inline-block;
      padding: 4px 26px 4px 10px;
      border-radius: 5px;
      margin-right: 10px;
      color: var(--w-900);
      background: var(--w-50);
      margin-bottom: 5px;
      white-space: nowrap;
      overflow: hidden;
      max-width: 100%;
      text-overflow: ellipsis;
    }

    .multiselect__tag-icon {
      cursor: pointer;
      margin-left: 7px;
      position: absolute;
      right: 0;
      top: 0;
      bottom: 0;
      font-weight: 700;
      font-style: initial;
      width: 22px;
      text-align: center;
      line-height: 22px;
      transition: all 0.2s ease;
      border-radius: 5px;
    }

    .multiselect__tag-icon:after {
      content: '×';
      color: var(--w-700);
      font-size: 14px;
    }

    .multiselect__tag-icon:focus,
    .multiselect__tag-icon:hover {
      background: var(--w-100);
    }

    .multiselect--active .multiselect__tags {
      border-color: var(--w-500);
    }

    .multiselect__input,
    .multiselect__single {
      position: relative;
      display: inline-block;
      min-height: 20px;
      line-height: 20px;
      border: none;
      border-radius: 5px;
      background: var(--white);
      padding: 0 0 0 5px;
      width: 100%;
      transition: border 0.1s ease;
      box-sizing: border-box;
      margin-bottom: 8px;
      vertical-align: top;
    }
  }
}

.kanban-loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex: 1;
  padding: var(--space-large);

  .loading-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    max-width: 400px;

    h3 {
      font-size: var(--font-size-medium);
      margin: var(--space-normal) 0;
      color: var(--s-700);

      .dark-mode & {
        color: var(--s-200);
      }
    }

    .loading-progress {
      font-size: var(--font-size-big);
      font-weight: var(--font-weight-bold);
      color: var(--w-500);
      margin-top: var(--space-smaller);

      .dark-mode & {
        color: var(--w-400);
      }
    }
  }

  .loading-spinner {
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: var(--space-normal);

    .spinner-circle {
      width: 12px;
      height: 12px;
      margin: 0 4px;
      border-radius: 50%;
      background-color: var(--w-400);
      animation: bounce 1.4s infinite ease-in-out both;

      &:nth-child(1) {
        animation-delay: -0.32s;
      }

      &:nth-child(2) {
        animation-delay: -0.16s;
      }
    }
  }
}

@keyframes bounce {
  0%,
  80%,
  100% {
    transform: scale(0);
  }
  40% {
    transform: scale(1);
  }
}

.load-more-container {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: var(--space-normal);
  margin-top: var(--space-normal);
  background-color: var(--white);
  border-radius: var(--border-radius-medium);
  box-shadow: var(--shadow-small);

  .dark-mode & {
    background-color: var(--b-700);
  }

  button {
    color: var(--w-500);
    font-weight: var(--font-weight-medium);

    &:hover {
      color: var(--w-600);
    }

    .dark-mode & {
      color: var(--s-200);

      &:hover {
        color: var(--s-100);
      }
    }
  }
}

.loading-more-indicator {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: var(--space-normal);
  color: var(--s-700);

  .spinner {
    width: 20px;
    height: 20px;
    margin-right: var(--space-small);
    border: 2px solid var(--s-200);
    border-top-color: var(--w-500);
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
</style>
