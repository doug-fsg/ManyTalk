<template>
  <div class="kanban-container" :class="{ 'dark-mode': isDarkMode }">
    <kanban-header
      :pipeline-name="selectedAttribute ? selectedAttribute.attribute_display_name : $t('KANBAN.TITLE')"
      :current-view="currentView"
      :pipelines="listTypeAttributes"
      @update:current-view="currentView = $event"
      @select-pipeline="selectPipeline"
      @search="handleSearch"
      @create-new="openCreateAttributeModal"
      @edit-kanban="editKanban"
      @delete-kanban="deleteKanban"
    />

    <div 
      v-if="showPipelineDropdown"
      class="pipeline-dropdown"
    >
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
      class="kanban-select-attribute"
      v-if="
        !selectedAttribute && attributes.length && listTypeAttributes.length
      "
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
      class="kanban-select-attribute"
      v-if="
        !selectedAttribute && attributes.length && !listTypeAttributes.length
      "
    >
      <div class="select-attribute-content">
        <h2>{{ $t('KANBAN.NO_KANBAN_ATTRIBUTES') }}</h2>
        <p>{{ $t('KANBAN.CREATE_KANBAN_ATTRIBUTE_DESCRIPTION') }}</p>
        <woot-button
          size="large"
          variant="primary"
          @click="goToAttributesSettings"
        >
          {{ $t('KANBAN.CREATE_ATTRIBUTE') }}
        </woot-button>
      </div>
    </div>

    <!-- Loading state para o carregamento de contatos -->
    <woot-loading-state
      v-if="isLoadingContacts"
      :message="loadingMessage"
    />

    <div v-else-if="selectedAttribute && !uiFlags.isFetching" class="kanban-board">
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
          />
        </draggable>
      </div>
      
      <!-- Botão de carregar mais -->
      <div 
        v-if="pagination && pagination.hasMore && !pagination.isLoadingMore" 
        class="load-more-container"
      >
        <woot-button
          variant="clear"
          size="small"
          @click="loadMoreContacts(false)"
        >
          {{ $t('KANBAN.LOAD_MORE_CONTACTS') }}
        </woot-button>
      </div>

      <!-- Indicador de carregamento -->
      <div 
        v-if="pagination && pagination.isLoadingMore"
        class="loading-more-indicator"
      >
        <span class="spinner"></span>
        {{ $t('KANBAN.LOADING_CONTACTS') }}
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
    <woot-modal :show.sync="showEditPipelineModal" :on-close="closeEditPipelineModal">
      <edit-attribute
        :selected-attribute="selectedAttribute"
        :is-updating="uiFlags.isUpdating"
        @on-close="closeEditPipelineModal"
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
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import draggable from 'vuedraggable';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { getRandomColor } from 'dashboard/helper/labelColor';
import { formatUnixDate } from 'shared/helpers/DateHelper';
import Vue from 'vue';
import Multiselect from 'vue-multiselect';
import { KanbanLogger } from '../utils/KanbanLogger';
import { KanbanOperationManager } from '../utils/KanbanOperationManager';
import { KanbanAttributeService } from '../utils/KanbanAttributeService';
import { PipelineCacheManager } from '../services/PipelineCacheManager';
import KanbanColumn from './KanbanColumn.vue';
import KanbanHeader from './Header.vue';
import EditAttribute from 'dashboard/routes/dashboard/settings/attributes/EditAttribute.vue';
import CreateAttributeModal from './CreateAttributeModal.vue';

// Criar um barramento de eventos local se não existir um global
const eventBus = new Vue();

export default {
  name: 'KanbanAttributes',
  components: {
    draggable,
    KanbanColumn,
    KanbanHeader,
    EditAttribute,
    CreateAttributeModal,
  },
  created() {
    this.initializeComponent();
  },
  mounted() {
    this.fetchAttributes();
    this.bus = this.$bus || eventBus;
    
    if (this.bus) {
      this.bus.$on(BUS_EVENTS.THEME_CHANGE, this.checkDarkMode);
      this.bus.$on('contact_attribute_updated', this.handleContactAttributeUpdate);
      this.bus.$on('contact_updated', this.handleContactUpdate);
      this.bus.$on('kanban_clear_updates', this.clearUpdateCache);
    }
    
    this.startCycleDetection();
    this.$el.addEventListener('scroll', this.updateScrollPosition);
    document.addEventListener('click', this.handleClickOutside);

    // Definir idioma correto
    const userLocale = this.$store.getters['auth/currentUser']?.ui_settings?.locale || 'pt_BR';
    if (this.$i18n.locale !== userLocale) {
      this.$i18n.locale = userLocale;
      this.$root.$i18n.locale = userLocale;
    }

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
      this.bus.$off('contact_attribute_updated', this.handleContactAttributeUpdate);
      this.bus.$off('contact_updated', this.handleContactUpdate);
      this.bus.$off('kanban_clear_updates', this.clearUpdateCache);
    }
    
    this.operationManager.clearOperations();
    this.logger.clear();

    this.$el.removeEventListener('scroll', this.updateScrollPosition);
    document.removeEventListener('click', this.handleClickOutside);
    cancelAnimationFrame(this.requestID);
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
      loadingProgress: null,
      loadingMessage: '',
      isLoadingInitialData: false,
      pagination: null,
      pipelineCacheManager: null,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'attributes/getUIFlags',
      attributes: 'attributes/getAttributes',
      contacts: 'contacts/getContacts',
      contactMeta: 'contacts/getMeta',
      currentUser: 'getCurrentUser',
    }),
    isDarkMode() {
      // Verifica se o modo escuro está ativado
      return this.$store.getters.getDarkMode;
    },
    listTypeAttributes() {
      // Filtrar apenas atributos do tipo "list" e model "contact_attribute"
      const filteredAttrs = this.attributes.filter(
        attr => attr.attribute_display_type === 'list' && attr.attribute_model === 'contact_attribute'
      );
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
      // Retorna as colunas filtradas se houver busca, caso contrário retorna todas as colunas
      return this.searchQuery ? this.filteredColumns : this.columns;
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
        console.log('Locale mudou para:', newLocale);
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
      const userLocale = this.$store.getters['auth/currentUser']?.ui_settings?.locale || 'pt_BR';
      this.initializeLocale(userLocale);
      await this.initializeServices();
      await this.loadInitialData();
    },
    initializeLocale(userLocale) {
      if (this.$i18n.locale !== userLocale) {
        this.$i18n.locale = userLocale;
        this.$root.$i18n.locale = userLocale;
      }
    },
    async initializeServices() {
      this.pipelineCacheManager = new PipelineCacheManager(this.$store);
      this.logger = new KanbanLogger(false);
      this.operationManager = new KanbanOperationManager(this.logger);
      this.attributeService = new KanbanAttributeService(this.$store, this.logger);
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
        console.log('Failed to show notification:', message);
      }
    },
    checkDarkMode() {
      // Método para atualizar o isDarkMode quando o tema mudar
    },
    async handleContactAttributeUpdate(contact, attribute, payload) {
      const attributeKey = Object.keys(attribute)[0];
      const attributeValue = attribute[attributeKey];
      const startTime = Date.now();

      // Verificar se esta atualização veio do próprio Kanban (para evitar loops)
      if (payload && payload._fromKanban) {
        this.logger.log('info', 'Ignorando atualização iniciada pelo Kanban', {
          contactId: contact.id,
          attribute: attributeKey,
          operation: payload._kanbanOperation
        });
        return;
      }

      // Log do início da operação
      this.logger.log('info', 'Iniciando atualização de atributo', {
        contactId: contact.id,
        attribute: attributeKey,
        value: attributeValue
      });

      // Verificar se já existe operação pendente
      if (this.operationManager.isOperationPending(contact.id)) {
        this.logger.log('warn', 'Operação pendente encontrada, aguardando...', {
          contactId: contact.id,
          attribute: attributeKey
        });
        return;
      }

      // Verificar se o atributo é o que estamos exibindo no Kanban
      if (this.selectedAttribute && attributeKey !== this.selectedAttribute.attribute_key) {
        this.logger.log('info', 'Atributo não corresponde ao Kanban atual, ignorando', {
          kanbanAttr: this.selectedAttribute.attribute_key,
          updateAttr: attributeKey
        });
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
          operation_id: operationId
        });

      } catch (error) {
        this.logger.log('error', 'Erro ao atualizar posição do card', {
          error,
          contactId: contact.id, 
          operationId
        });
        this.operationManager.completeOperation(operationId, false);
        
        // Tracking do erro
        this.trackEvent('card_move_error', {
          contact_id: contact.id,
          error: error.message,
          operation_id: operationId
        });
      }
    },

    async updateCardPosition(contact, newColumn, operationId) {
      console.log('[KanbanDebug] Iniciando updateCardPosition:', {
        contactId: contact.id,
        newColumn,
        operationId,
        contact: JSON.stringify(contact, null, 2)
      });

      const previousColumn = this.getCurrentColumn(contact.id);

      // Atualizar UI primeiro (otimista)
      this.updateColumnsLocally(contact, newColumn);

      try {
        // Atualizar no servidor usando o Vuex store
        if (this.selectedAttribute) {
          // Preparar dados de tracking de tempo
          const now = new Date().toISOString();
          
          console.log('[KanbanDebug] Estado atual do contato:', {
            additional_attributes: contact.additional_attributes,
            custom_attributes: contact.custom_attributes
          });

          // Garantir que additional_attributes existe
          let additionalAttributes = contact.additional_attributes || {};
          console.log('[KanbanDebug] additionalAttributes inicial:', additionalAttributes);
          
          // Criar uma cópia profunda para evitar referências
          additionalAttributes = JSON.parse(JSON.stringify(additionalAttributes));
          
          // Garantir que a estrutura base existe
          if (!additionalAttributes.kanban) {
            console.log('[KanbanDebug] Criando estrutura kanban');
            additionalAttributes.kanban = {};
          }
          
          const pipelineId = this.selectedAttribute.id;
          console.log('[KanbanDebug] Pipeline ID:', pipelineId);
          
          // Garantir que a estrutura do pipeline existe
          if (!additionalAttributes.kanban[pipelineId]) {
            console.log('[KanbanDebug] Criando estrutura do pipeline');
            additionalAttributes.kanban[pipelineId] = {};
          }
          
          // Garantir que stage_tracking existe
          if (!additionalAttributes.kanban[pipelineId].stage_tracking) {
            console.log('[KanbanDebug] Criando estrutura stage_tracking');
            additionalAttributes.kanban[pipelineId].stage_tracking = {};
          }
          
          // Atualizar o estágio atual
          const newStage = {
            stage_id: newColumn,
            entered_at: now
          };
          
          console.log('[KanbanDebug] Novo estágio:', newStage);
          
          // Atualizar stage_tracking
          additionalAttributes.kanban[pipelineId].stage_tracking.current = newStage;
          
          console.log('[KanbanDebug] Estrutura final:', {
            additionalAttributes: JSON.stringify(additionalAttributes, null, 2)
          });
          
          const contactParams = {
            id: contact.id,
            custom_attributes: {
              [this.selectedAttribute.attribute_key]: newColumn
            },
            additional_attributes: additionalAttributes
          };

          console.log('[KanbanDebug] Parâmetros para atualização:', {
            contactParams: JSON.stringify(contactParams, null, 2)
          });

          await this.$store.dispatch('contacts/update', contactParams);
          
          console.log('[KanbanDebug] Atualização realizada com sucesso');
          
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
            operation_id: operationId
          });
        }
      } catch (error) {
        console.error('[KanbanDebug] Erro ao atualizar posição:', error);
        
        // Reverter mudança local em caso de erro
        this.revertLocalUpdate(contact, previousColumn);
        this.operationManager.completeOperation(operationId, false);

        // Notificar o usuário
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('KANBAN.ERRORS.UPDATE_FAILED')
        });
      }
    },

    getCurrentColumn(contactId) {
      for (const column of this.columns) {
        if (column.items.some(item => item.id === contactId)) {
          return column.title;
        }
      }
      return null;
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
        previousColumn
      });
      this.updateColumnsLocally(contact, previousColumn);
    },

    trackEvent(event, data = {}) {
      if (window.$chatwoot?.analytics) {
        window.$chatwoot.analytics.track(`kanban_${event}`, {
          ...data,
          timestamp: new Date().toISOString(),
          account_id: this.$store.getters.getCurrentAccountId
        });
      }
    },

    hasCardError(contactId) {
      if (!this.operationManager) return false;
      const operation = Array.from(this.operationManager.operations.values())
        .find(op => op.cardId === contactId);
      return operation && operation.status === 'failed';
    },

    handleSearch() {
      // Debounce para evitar sobrecarga em buscas rápidas
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(() => {
        if (!this.searchQuery || this.searchQuery.trim() === '') {
          this.filteredColumns = [...this.columns];
          return;
        }

        const query = this.searchQuery.toLowerCase();
        this.filteredColumns = this.columns.map(column => {
          const filteredItems = column.items.filter(contact => {
            const name = (contact.name || '').toLowerCase();
            const email = (contact.email || '').toLowerCase();
            const phone = (contact.phone_number || '').toLowerCase();
            
            return (
              name.includes(query) || 
              email.includes(query) || 
              phone.includes(query)
            );
          });
          
          return {
            ...column,
            items: filteredItems,
          };
        });
        
        this.logger.log('info', 'Busca realizada', {
          query: this.searchQuery,
          resultCount: this.filteredColumns.reduce((sum, col) => sum + col.items.length, 0)
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
      if (this.selectedAttribute && this.selectedAttribute.attribute_key === attributeKey) {
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
      const pipelineId = this.selectedAttribute.id;
        
      try {
        // Ativar o estado de loading
        this.isLoadingContacts = true;
        this.loadingMessage = this.$t('KANBAN.LOADING_CONTACTS');

        // Inicializar ou redefinir o estado da paginação
        this.pagination = {
          currentPage: 0,
          totalPages: 0,
          hasMore: true,
          isLoadingMore: false,
        };

        // Limpar contatos existentes ao carregar do início
        this.$store.commit('contacts/CLEAR_CONTACTS');

        // Carregar as duas primeiras páginas
        await this.loadMoreContacts(true);

        // Configurar as colunas com os contatos carregados
        this.setupColumns();
      } catch (error) {
        console.error('❌ Erro ao carregar contatos:', error.message);
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('KANBAN.ERRORS.LOAD_FAILED'),
        });
      } finally {
          this.isLoadingContacts = false;
      }
    },

    async loadMoreContacts(isInitialLoad = false) {
      if (this.pagination.isLoadingMore || (!isInitialLoad && !this.pagination.hasMore)) {
          return;
        }
        
      try {
        this.pagination.isLoadingMore = true;
        const startPage = isInitialLoad ? 1 : this.pagination.currentPage + 1;
        const endPage = isInitialLoad ? 2 : startPage;

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

        const existingContacts = [...this.$store.getters['contacts/getContacts']];

        for (let page = startPage; page <= endPage; page += 1) {
          if (page > 1 && !this.pagination.hasMore) break;

          const contacts = await this.$store.dispatch('contacts/filter', {
                  page,
            queryPayload,
            resetState: false,
          });

          const meta = this.$store.getters['contacts/getMeta'];
          this.pagination.currentPage = page;
          this.pagination.totalPages = Math.ceil(meta.count / 15);
          this.pagination.hasMore = page < this.pagination.totalPages;

          if (!contacts || contacts.length === 0) {
            this.pagination.hasMore = false;
            break;
          }

          // Filtrar contatos duplicados
          const newContacts = contacts.filter(
            contact => !existingContacts.some(existing => existing.id === contact.id)
          );

          if (newContacts.length > 0) {
            this.$store.commit('contacts/SET_CONTACTS', [
              ...existingContacts,
              ...newContacts,
            ]);
            existingContacts.push(...newContacts);
          }
        }

        // Atualizar o cache do pipeline
        this.pipelineCacheManager.updateCache(this.selectedAttribute.id, this.pagination);
      } catch (error) {
        console.error('❌ Erro ao carregar mais contatos:', error.message);
        if (!isInitialLoad) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
            message: this.$t('KANBAN.ERRORS.LOAD_MORE_FAILED'),
        });
        }
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
      if (now - this.lastColumnUpdateTime < 1500) { // Aumentado para 1.5 segundos
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Limitando taxa de atualizações de coluna');
        }
        
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
        timestamp: now
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
      
      // Inicializa a filteredColumns com todas as colunas
      this.filteredColumns = [...this.columns];
      
      // Debug log para mostrar o conteúdo de cada coluna
      this.logColumnsContent();

      // Forçar atualização imediata da UI
      this.$nextTick(() => {
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
    async onItemMoved({ contactId, sourceColumnId, targetColumnId, sourceColumnTitle, targetColumnTitle }) {
      // Verificar se o contato existe
      const contact = this.contacts.find(c => c.id === contactId);
      if (!contact || !this.selectedAttribute) return;

      try {
        // Preparar dados de tracking de tempo
        const now = new Date().toISOString();
        
        // Criar estrutura base se não existir
        let additionalAttributes = contact.additional_attributes || {};
        
        // Criar uma cópia profunda para evitar referências
        additionalAttributes = JSON.parse(JSON.stringify(additionalAttributes));
        
        // Garantir que a estrutura kanban existe
        if (!additionalAttributes.kanban) {
          additionalAttributes.kanban = {};
        }
        
        // Garantir que a estrutura do pipeline existe
        if (!additionalAttributes.kanban[this.selectedAttribute.id]) {
          additionalAttributes.kanban[this.selectedAttribute.id] = {};
        }
        
        // Garantir que stage_tracking existe
        if (!additionalAttributes.kanban[this.selectedAttribute.id].stage_tracking) {
          additionalAttributes.kanban[this.selectedAttribute.id].stage_tracking = {};
        }
        
        // Atualizar o estágio atual
        additionalAttributes.kanban[this.selectedAttribute.id].stage_tracking.current = {
          stage_id: targetColumnTitle,
          entered_at: now
        };

        // Atualizar o contato
        const contactParams = {
          id: contactId,
          custom_attributes: {
            [this.selectedAttribute.attribute_key]: targetColumnTitle
          },
          additional_attributes: additionalAttributes
        };

        // Atualizar no servidor
        await this.$store.dispatch('contacts/update', contactParams);

        // Forçar atualização da UI
        this.$nextTick(() => {
          this.setupColumns();
        });

      } catch (error) {
        // Reverter a mudança local
        this.revertLocalUpdate(contact, sourceColumnTitle);
        
        // Notificar o usuário
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('KANBAN.ERRORS.UPDATE_FAILED')
        });
      }
    },
    openContact(contactId) {
      // Abre a página de detalhes do contato
      this.$router.push(frontendURL(
        `accounts/${this.$route.params.accountId}/contacts/${contactId}`
      ));
    },
    goToAttributesSettings() {
      // Navegar para a página de configurações de atributos
      this.$router.push(frontendURL(
        `accounts/${this.$route.params.accountId}/settings/custom-attributes`
      ));
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
        this.colorMap[label] = getRandomColor(Object.keys(this.colorMap).length);
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
    
    handleAttributeCreated() {
      this.showCreateAttributeModal = false;
        this.fetchAttributes();
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
          'novo lead': '#36B37E',        // Verde
          'em contato': '#00B8D9',       // Azul claro
          'qualificado': '#6554C0',      // Roxo
          'proposta enviada': '#FFAB00', // Laranja 
          'negociação': '#FF8B00',       // Laranja escuro
          'fechado ganho': '#36B37E',    // Verde
          'fechado perdido': '#FF5630',  // Vermelho
          'em andamento': '#00C7E6',     // Azul cyan
          'aguardando': '#6B778C',       // Cinza
          'suspenso': '#aaaaaa',         // Cinza claro
          'cancelado': '#FF5630',        // Vermelho
          'finalizado': '#36B37E',       // Verde
        };
        
        // Verificar se existe uma cor predefinida para este estágio (case-insensitive)
        const stageNameLower = stageName.toLowerCase();
        const stageEntries = Object.entries(stageColors);
        
        // Usando método de array em vez de loop for...of
        const matchingStage = stageEntries.find(([key]) => 
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
          console.log('[KanbanDebug] Contact not found:', this.cardToRemove);
          return;
        }

        // Update the contact
        await this.$store.dispatch('contacts/update', {
          id: contact.id,
          custom_attributes: {
            [this.selectedAttribute.attribute_key]: null
          }
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
        console.log('[KanbanDebug] Error removing card:', error);
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
      if (payload._fromKanban || payload._kanbanOperation) {
        this.logger.log('info', 'Ignorando atualização iniciada pelo Kanban', {
          contactId: payload.id,
          operation: payload._kanbanOperation
        });
        return;
      }
      
      // Se não há atributo selecionado, não há o que atualizar
      if (!this.selectedAttribute) {
        return;
      }
      
      // Extrair o atributo relevante
      const { attribute_key: attributeKey } = this.selectedAttribute;
      const attributeValue = this.getAttributeValue(payload.custom_attributes, attributeKey);
      
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
      this.logger.log('info', 'Atualizando posição do card localmente após alteração externa', {
        contactId: payload.id,
        from: currentColumn,
        to: attributeValue
      });
      
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
        this.logger.log('warn', 'Trava de sincronização liberada por timeout de segurança');
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
      const conversationUrl = frontendURL(`accounts/${this.$route.params.accountId}/conversations/${conversationId}`);
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
    async confirmDeletePipeline() {
      try {
        const contactsUsingPipeline = this.contacts.filter(contact => {
          const customAttributes = contact.custom_attributes || {};
          const attributeValue = customAttributes[this.selectedAttribute.attribute_key];
          return attributeValue !== undefined && attributeValue !== null && attributeValue !== '';
        });

        if (contactsUsingPipeline.length > 0) {
          this.showDeletePipelineModal = false;
          this.safeShowNotification(
            'error',
            this.$t('KANBAN.ERRORS.PIPELINE_IN_USE')
          );
          return;
        }

        await this.$store.dispatch('attributes/delete', this.selectedAttribute.id);
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
        this.safeShowNotification('error', this.$t('KANBAN.ERRORS.NO_PIPELINE_SELECTED'));
        return;
      }
      this.showEditPipelineModal = true;
    },
    deleteKanban() {
      if (!this.selectedAttribute) {
        this.safeShowNotification('error', this.$t('KANBAN.ERRORS.NO_PIPELINE_SELECTED'));
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
      const oldValue = contact.custom_attributes[this.selectedAttribute.attribute_key];
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
        this.pipelineCacheManager.updateCache(this.selectedAttribute.id, this.pagination);
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
        lastUpdated: Date.now()
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
            [this.selectedAttribute.attribute_key]: newColumnValue
          }
        };

        this.pipelineCache[pipelineId] = {
          ...cachedData,
          contacts,
          lastUpdated: Date.now()
        };

        // Forçar atualização do store para refletir a mudança imediatamente
        this.$store.commit('contacts/SET_CONTACTS', contacts);
      }
    },
    async handleDealValueUpdate({ contactId, value, additionalAttributes, columnId }) {
      try {
        // Atualizar o cache local otimisticamente
        this.pipelineCacheManager.updateContactInCache(contactId, {
          additional_attributes: additionalAttributes
        });
        
        // Atualizar no servidor
        await this.$store.dispatch('contacts/update', {
          id: contactId,
          additional_attributes: additionalAttributes
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
        contactCount: contactsToMigrate.length
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
                value
              },
              stage_tracking: {
                current: {
                  stage_id: contact.custom_attributes?.[this.getAttributeKeyById(pipelineId)],
                  entered_at: new Date().toISOString()
                }
              }
            };
          });
          
          // Atualizar contato com nova estrutura
          const updatedAdditionalAttributes = {
            ...additionalAttributes,
            kanban
          };
          
          // Remover estrutura antiga
          delete updatedAdditionalAttributes.deal_values;
          
          await this.$store.dispatch('contacts/update', {
            id: contact.id,
            additional_attributes: updatedAdditionalAttributes
          });
          
          this.logger.log('info', 'Contato migrado com sucesso', {
            contactId: contact.id
          });
        } catch (error) {
          this.logger.log('error', 'Erro ao migrar contato', {
            contactId: contact.id,
            error
          });
        }
      });
    },
    
    getAttributeKeyById(attributeId) {
      if (!this.attributes || !this.attributes.length) return null;
      
      const attribute = this.attributes.find(attr => attr.id === parseInt(attributeId, 10));
      return attribute ? attribute.attribute_key : null;
    },
    async migrateContactsStageTracking() {
      if (!this.selectedAttribute || !this.contacts) return;

      console.log('[KanbanDebug] Iniciando verificação de contatos para migração');

      const contactsToMigrate = this.contacts.filter(contact => {
        const additionalAttributes = contact.additional_attributes || {};
        const kanban = additionalAttributes.kanban || {};
        const pipelineData = kanban[this.selectedAttribute.id];
        
        const needsMigration = !pipelineData?.stage_tracking;
        if (needsMigration) {
          console.log('[KanbanDebug] Contato precisa de migração:', {
            contactId: contact.id,
            additionalAttributes: JSON.stringify(additionalAttributes, null, 2)
          });
        }
        
        return needsMigration;
      });

      console.log('[KanbanDebug] Contatos para migrar:', contactsToMigrate.length);

      for (const contact of contactsToMigrate) {
        try {
          const now = new Date().toISOString();
          const currentStage = contact.custom_attributes[this.selectedAttribute.attribute_key];
          
          console.log('[KanbanDebug] Migrando contato:', {
            contactId: contact.id,
            currentStage,
            additionalAttributes: contact.additional_attributes
          });

          let additionalAttributes = contact.additional_attributes || {};
          additionalAttributes = JSON.parse(JSON.stringify(additionalAttributes));

          if (!additionalAttributes.kanban) {
            additionalAttributes.kanban = {};
          }
          
          if (!additionalAttributes.kanban[this.selectedAttribute.id]) {
            additionalAttributes.kanban[this.selectedAttribute.id] = {};
          }

          additionalAttributes.kanban[this.selectedAttribute.id].stage_tracking = {
            current: {
              stage_id: currentStage || this.columns[0]?.title,
              entered_at: now
            }
          };

          console.log('[KanbanDebug] Nova estrutura do contato:', {
            contactId: contact.id,
            additionalAttributes: JSON.stringify(additionalAttributes, null, 2)
          });

          await this.$store.dispatch('contacts/update', {
            id: contact.id,
            additional_attributes: additionalAttributes
          });

          console.log('[KanbanDebug] Contato migrado com sucesso:', contact.id);
        } catch (error) {
          console.error('[KanbanDebug] Erro ao migrar contato:', {
            contactId: contact.id,
            error: error.message
          });
        }
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
    
    h2 {
      font-size: var(--font-size-big);
      margin-bottom: var(--space-normal);
    }
    
    p {
      margin-bottom: var(--space-large);
      color: var(--s-700);
      
      .dark-mode & {
        color: var(--s-300);
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
      content: "×";
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
  0%, 80%, 100% {
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