<template>
  <div class="kanban-container" :class="{ 'dark-mode': isDarkMode }">
    <kanban-header
      :pipeline-name="selectedAttribute ? selectedAttribute.attribute_display_name : $t('KANBAN.TITLE')"
      :is-admin="isAdmin"
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

    <div v-if="selectedAttribute && !uiFlags.isFetching" class="kanban-board">
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
            :operation-manager="operationManager"
            @item-moved="onItemMoved"
            @view-contact="openContact"
            @remove-card="removeCardFromKanban"
            @update:items="handleColumnItemsUpdate"
            @open-conversation="openConversation"
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

    <woot-modal
      :show.sync="showCreateAttributeModal"
      :on-close="closeCreateAttributeModal"
    >
      <div class="attribute-modal">
        <woot-modal-header
          :header-title="$t('KANBAN.CREATE_NEW_ATTRIBUTE')"
          :header-content="$t('KANBAN.CREATE_NEW_ATTRIBUTE_DESC')"
        />
        <div class="attribute-form">
          <woot-input
            v-model="newAttributeData.display_name"
            :label="$t('ATTRIBUTES_MGMT.ADD.FORM.NAME.LABEL')"
            :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
            class="attribute-input"
          />
          <label 
            class="block text-sm font-medium leading-5 text-slate-700 dark:text-slate-300 pt-2 pb-1"
          >
            {{ $t('ATTRIBUTES_MGMT.ADD.FORM.NAME.LABEL') }}
          </label>
          <tags-input
            v-model="attributeValues"
            :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LIST.PLACEHOLDER')"
            :allow-duplicates="false"
            class="attribute-input"
          />
          <div class="modal-footer">
            <woot-button variant="clear" @click="closeCreateAttributeModal">
              {{ $t('ATTRIBUTES_MGMT.ADD.CANCEL_BUTTON_TEXT') }}
            </woot-button>
            <woot-button variant="primary" @click="createKanbanAttribute">
              {{ $t('ATTRIBUTES_MGMT.ADD.SUBMIT') }}
            </woot-button>
          </div>
        </div>
      </div>
    </woot-modal>

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
import TagsInput from 'shared/components/ui/TagsInput';
import { KanbanLogger } from '../utils/KanbanLogger';
import { KanbanOperationManager } from '../utils/KanbanOperationManager';
import { KanbanAttributeService } from '../utils/KanbanAttributeService';
import KanbanColumn from './KanbanColumn.vue';
import KanbanHeader from './Header.vue';
import WootDeleteModal from 'dashboard/components/widgets/modal/DeleteModal';
import EditAttribute from 'dashboard/routes/dashboard/settings/attributes/EditAttribute.vue';
import WootConfirmDeleteModal from 'dashboard/components/widgets/modal/ConfirmDeleteModal';

// Criar um barramento de eventos local se não existir um global
const eventBus = new Vue();

export default {
  name: 'KanbanAttributes',
  components: {
    draggable,
    TagsInput,
    KanbanColumn,
    KanbanHeader,
    WootDeleteModal,
    EditAttribute,
    WootConfirmDeleteModal,
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
      newAttributeData: {
        display_name: '',
      },
      attributeValues: [],
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
      _searchDebounce: null,
      _setupColumnsTimeout: null,
      showRemoveCardModal: false,
      cardToRemove: null,
      showEditPipelineModal: false,
      showDeletePipelineModal: false,
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
    selectedAttribute(newVal) {
      if (newVal) {
        this.fetchContacts();
        this.setupColumns();
      }
    },
    // Observa mudanças na lista de atributos para selecionar automaticamente
    listTypeAttributes: {
      immediate: true,
      handler(newAttrs) {
        if (!this.selectedAttribute && newAttrs.length > 0) {
          this.selectedAttribute = this.defaultAttribute;
        }
      },
    },
    // Observa mudanças nos contatos para atualizar as colunas
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
  },
  created() {
    this.logger = new KanbanLogger(this.debugMode);
    this.operationManager = new KanbanOperationManager(this.logger);
    this.attributeService = new KanbanAttributeService(this.$store, this.logger);
  },
  mounted() {
    this.fetchAttributes();
    
    // Usar o bus global se existir, caso contrário, usar o local
    this.bus = this.$bus || eventBus;
    
    if (this.bus) {
      this.bus.$on(BUS_EVENTS.THEME_CHANGE, this.checkDarkMode);
      this.bus.$on(
        'contact_attribute_updated',
        this.handleContactAttributeUpdate
      );
      this.bus.$on('contact_updated', this.handleContactUpdate);
      this.bus.$on('kanban_clear_updates', this.clearUpdateCache);
    }
    
    // Iniciar sistema de detecção de ciclos
    this.startCycleDetection();

    this.$el.addEventListener('scroll', this.updateScrollPosition);
    document.addEventListener('click', this.handleClickOutside);
  },
  beforeDestroy() {
    clearTimeout(this.updateDebounceTimeout);
    clearTimeout(this._searchDebounce);
    clearTimeout(this._setupColumnsTimeout);
    
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
  methods: {
    checkDarkMode() {
      // Método para atualizar o isDarkMode quando o tema mudar
    },
    debug(message, data) {
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log(`[KanbanDebug] ${message}`, data || '');
      }
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
      this.logger.log('info', 'Iniciando atualização de posição', {
        contactId: contact.id,
        newColumn,
        operationId
      });

      const previousColumn = this.getCurrentColumn(contact.id);

      // Atualizar UI primeiro (otimista)
      this.updateColumnsLocally(contact, newColumn);

      try {
        // Atualizar no servidor usando o Vuex store
        if (this.selectedAttribute) {
          const contactParams = {
            id: contact.id,
            custom_attributes: {
              [this.selectedAttribute.attribute_key]: newColumn
            }
          };

          await this.$store.dispatch('contacts/update', contactParams);
          
          this.operationManager.completeOperation(operationId, true);
          
          this.logger.log('info', 'Posição atualizada com sucesso', {
            contactId: contact.id,
            operationId
          });
  
          // Tracking de sucesso
          this.trackEvent('card_move_completed', {
            contact_id: contact.id,
            from_column: previousColumn,
            to_column: newColumn,
            operation_id: operationId,
            duration: Date.now() - this.operationManager.getOperation(operationId).timestamp
          });
        }
      } catch (error) {
        // Reverter mudança local em caso de erro
        this.revertLocalUpdate(contact, previousColumn);
        this.operationManager.completeOperation(operationId, false);
        
        this.logger.log('error', 'Erro ao atualizar posição do card', {
          error,
          contactId: contact.id,
          operationId
        });

        // Tracking do erro
        this.trackEvent('card_move_error', {
          contact_id: contact.id,
          error: error.message,
          operation_id: operationId
        });

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

    // Método para mostrar notificações de forma segura
    safeShowNotification(type, message) {
      if (this.bus) {
        this.bus.$emit('show-alert', {
          message: message,
          type: type,
        });
      }
    },

    handleSearch() {
      // Debounce para evitar sobrecarga em buscas rápidas
      clearTimeout(this._searchDebounce);
      this._searchDebounce = setTimeout(() => {
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
      this.debug(this.$t('KANBAN.DEBUG.RECEIVED_EVENT_REMOVED'), { 
        contactId: contact.id, 
        attributeKey,
        selectedAttribute: this.selectedAttribute?.attribute_key
      });
      
      // Se o kanban estiver aberto e for o mesmo atributo que foi removido
      if (
        this.selectedAttribute && 
        this.selectedAttribute.attribute_key === attributeKey && 
        !this.processingUpdate // Adiciona verificação para evitar loop
      ) {
        this.logger.log('info', this.$t('KANBAN.CONTACT_ATTRIBUTE_REMOVED'));
        
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
      this.debug(this.$t('KANBAN.DEBUG.RECEIVED_EVENT_REMOVED'), { contactId, attributeKey });
      // Este evento é acionado quando um atributo é removido a partir do Kanban
      // Já com a flag fromKanban, então apenas atualizamos as colunas sem emitir outros eventos
      if (this.selectedAttribute && this.selectedAttribute.attribute_key === attributeKey) {
        this.debug(this.$t('KANBAN.DEBUG.UPDATING_COLUMNS'));
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
      try {
        this.logger.log('info', 'Iniciando busca de contatos');
        
        // Limpar contatos anteriores e buscar a primeira página
        await this.$store.dispatch('contacts/get', { 
          page: 1, 
          per_page: 100  // Aumentamos para reduzir número de chamadas
        });
        
        // Calcular número total de páginas necessárias
        const totalPages = Math.ceil(this.contactMeta.count / 100);
        const maxPages = 3;  // Limite máximo de páginas para evitar sobrecarga
        
        // Logging para diagnóstico
        this.logger.log('info', 'Planejamento de carregamento de contatos', {
          total: this.contactMeta.count,
          pages: totalPages,
          limitedTo: Math.min(totalPages, maxPages)
        });
        
        // Carregar páginas adicionais se necessário
        if (totalPages > 1) {
          const pagesToLoad = Math.min(totalPages, maxPages);
          
          // Usar Promise.all para carregar em paralelo e melhorar performance
          const pagePromises = [];
          
          for (let page = 2; page <= pagesToLoad; page++) {
            pagePromises.push(
              this.$store.dispatch('contacts/get', { 
              page, 
                per_page: 100, 
              append: true 
              })
            );
          }
          
          await Promise.all(pagePromises);
        }
        
        // Se o total exceder o que carregamos, mostrar aviso
        if (totalPages > maxPages) {
          this.safeShowNotification(
            'info',
            this.$t('KANBAN.PARTIAL_CONTACTS_LOADED')
          );
        }
        
        // Configurar colunas com os contatos carregados
        this.setupColumns();
        
      } catch (error) {
        this.logger.log('error', 'Erro ao buscar contatos', { error });
        this.safeShowNotification(
          'error',
          this.$t('CONTACTS.LIST.FETCH_ERROR')
        );
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
        clearTimeout(this._setupColumnsTimeout);
        
        // Agendar apenas uma atualização futura
        this._setupColumnsTimeout = setTimeout(() => {
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
    async onItemMoved({ contactId, sourceColumnId, targetColumnId, sourceColumnTitle, targetColumnTitle, timestamp }) {
      console.log('[KanbanDebug] Recebido evento item-moved', {
        contactId,
        sourceColumnId,
        targetColumnId,
        sourceColumnTitle,
        targetColumnTitle,
        timestamp
      });

      // Verificar se o contato existe
      const contact = this.contacts.find(c => c.id === contactId);
      if (!contact) {
        console.error('[KanbanDebug] Contato não encontrado', { contactId });
        return;
      }

      console.log('[KanbanDebug] Contato encontrado', { contact });

      // Verificar se o atributo está selecionado
      if (!this.selectedAttribute) {
        console.error('[KanbanDebug] Nenhum atributo selecionado');
        return;
      }

      try {
        // Preparar dados para atualização
        const contactParams = {
          id: contactId,
          custom_attributes: {
            [this.selectedAttribute.attribute_key]: targetColumnTitle
          }
        };

        console.log('[KanbanDebug] Iniciando atualização do contato', { 
          contactParams,
          attributeKey: this.selectedAttribute.attribute_key,
          store: this.$store
        });

        // Atualizar o contato usando o store
        await this.$store.dispatch('contacts/update', contactParams);
        
        console.log('[KanbanDebug] Contato atualizado com sucesso');
      } catch (error) {
        console.error('[KanbanDebug] Erro ao atualizar contato', { 
          error,
          errorMessage: error.message,
          errorStack: error.stack
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
      this.newAttributeData = {
        display_name: '',
      };
      this.attributeValues = [];
    },
    
    closeCreateAttributeModal() {
      this.showCreateAttributeModal = false;
      this.newAttributeData = {
        display_name: '',
      };
      this.attributeValues = [];
    },
    
    async createKanbanAttribute() {
      // Validar campos
      if (!this.newAttributeData.display_name || !this.attributeValues.length) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('ATTRIBUTES_MGMT.ADD.FORM.VALIDATION_ERROR'),
        });
        return;
      }
      
        // Criar atributo personalizado do tipo lista
        const attributeData = {
          attribute_display_name: this.newAttributeData.display_name,
          attribute_display_type: 'list',
          attribute_description: this.newAttributeData.display_name,
          attribute_key: this.newAttributeData.display_name.toLowerCase().replace(/\s+/g, '_'),
          attribute_values: this.attributeValues,
          attribute_model: 'contact_attribute',
        };
        
      this.$store.dispatch('attributes/create', attributeData)
        .then(() => {
        // Fechar o modal e recarregar atributos
        this.closeCreateAttributeModal();
        this.fetchAttributes();
        
          this.safeShowNotification(
            'success',
            this.$t('ATTRIBUTES_MGMT.API.CREATE_SUCCESS')
          );
        })
        .catch(() => {
                    this.safeShowNotification(
            'error',
            this.$t('ATTRIBUTES_MGMT.API.CREATE_ERROR')
          );
        });
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
    confirmRemoveCard() {
      const contactId = this.cardToRemove;
      this.showRemoveCardModal = false;
      
      if (!contactId || !this.selectedAttribute) {
        return;
      }
      
      const attrKey = this.selectedAttribute.attribute_key;
      this.logger.log('info', this.$t('KANBAN.DEBUG.REMOVING_CARD'), { contactId, attrKey });
      
      // Gerar ID de operação para rastreamento
      const operationId = `remove-${contactId}-${attrKey}-${Date.now()}`;
      
      // Registrar a operação no gerenciador
      if (!this.operationManager.registerOperation(contactId, 'remove')) {
        this.logger.log('warn', this.$t('KANBAN.DEBUG.OPERATION_REGISTER_FAILED'), { contactId });
        return;
      }
      
      this.attributeService.removeContactAttribute(contactId, attrKey, operationId)
        .then(() => {
          this.logger.log('info', this.$t('KANBAN.DEBUG.CARD_REMOVED'));
          this.safeShowNotification(
            'success',
            this.$t('KANBAN.CARD_REMOVED_SUCCESS')
          );
        
          // Atualizar as colunas localmente
          this.setupColumnsWithLock();
          this.operationManager.completeOperation(operationId, true);
        })
        .catch(error => {
          this.logger.log('error', 'Erro ao remover card', { contactId, error });
          this.safeShowNotification(
            'error',
            this.$t('CONTACTS.EDIT.API.DELETE_ERROR')
          );
          this.operationManager.completeOperation(operationId, false);
        });
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
      clearTimeout(this._searchDebounce);
      clearTimeout(this._setupColumnsTimeout);
      
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
      // Verificar se podemos atualizar a coluna agora ou precisamos esperar
      const now = Date.now();
      if (now - this.lastColumnUpdateTime < 1200) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Limitando taxa de atualizações da coluna, reagendando...');
        }
        // Reagendar a atualização para mais tarde
        setTimeout(() => {
          if (!this.syncLock && !this.processingUpdate) {
            this.setupColumnsWithLock();
          }
        }, 1500);
        return;
      }
      
      // Registrar esta atualização
      this.lastColumnUpdateTime = now;
      
      // Processar a atualização de coluna normal
      this.setupColumns();
    },
    // Método para debugging das colunas
    logColumnsContent() {
      if (!this.debugMode) return;
      
      // eslint-disable-next-line no-console
      console.log('[KanbanLog] === CONTEÚDO DAS COLUNAS ===');
      
      this.columns.forEach(column => {
        // eslint-disable-next-line no-console
        console.log(
          `[KanbanLog] Coluna: "${column.title}" - ${column.items.length} itens`
        );
        
        if (column.items && column.items.length) {
          column.items.forEach(contact => {
            // eslint-disable-next-line no-console
            console.log(
              `[KanbanLog]   - Contato ID: ${contact.id}, Nome: ${contact.name}, Atributos: `,
              contact.custom_attributes
            );
          });
        }
      });
    },
    // Adicionar este novo método para limpar o cache de atualizações
    clearUpdateCache() {
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanLog] Limpando cache de atualizações');
      }
      this.recentUpdates.clear();
      this.processingUpdate = false;
      this.releaseSyncLock();
    },
    startCycleDetection() {
      // Limpar qualquer timer existente
      this.stopCycleDetection();
      
      // Iniciar novo timer para monitorar atualizações, mas com frequência menor
      this.cycleDetectionTimer = setInterval(() => {
        try {
        // Registrar timestamp da atualização
        const now = Date.now();
        
        // Manter apenas os últimos 10 segundos de atividade
        const tenSecondsAgo = now - 10000;
        this.updateTimestamps = this.updateTimestamps.filter(
          timestamp => timestamp > tenSecondsAgo
        );
        
          // Verificar frequência de atualizações - mais conservador
          if (this.updateTimestamps.length > 20) {
            // Mais de 20 atualizações em 10 segundos indica um ciclo
          if (!this.cycleDetectionActive) {
            this.cycleDetectionActive = true;
            
              this.logger.log('warn', 'Ciclo de atualizações detectado! Resetando componente...');
              
              // Parar o ciclo de detecção durante o reset
              this.stopCycleDetection();
            
            // Reset completo
            this.resetAllLocks();
              
              // Usar método seguro para notificação
              this.safeShowNotification(
                'warning',
                this.$t('KANBAN.ERRORS.TOO_MANY_UPDATES')
              );
              
              // Restore após um tempo mais longo
            setTimeout(() => {
              this.cycleDetectionActive = false;
                // Reiniciar detecção com delay
                setTimeout(() => {
                  if (!this.cycleDetectionTimer) {
                    this.startCycleDetection();
                  }
                }, 3000);
              }, 8000);
            }
          }
        } catch (error) {
          // Proteção contra erros no sistema de detecção
          this.logger.log('error', 'Erro no sistema de detecção de ciclos', { error });
          this.stopCycleDetection();
        }
      }, 2000); // Aumentado para 2 segundos para reduzir sobrecarga
    },
    stopCycleDetection() {
      if (this.cycleDetectionTimer) {
        clearInterval(this.cycleDetectionTimer);
        this.cycleDetectionTimer = null;
      }
    },
    handleColumnItemsUpdate({ columnId, items }) {
      // Atualizar os itens da coluna específica
      const columnIndex = this.columns.findIndex(col => col.id === columnId);
      if (columnIndex !== -1) {
        this.columns[columnIndex].items = items;
      }
    },
    openConversation(conversationId) {
      // Navegar para a página da conversa
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
          return customAttributes[this.selectedAttribute.attribute_key] !== undefined;
        });

        if (contactsUsingPipeline.length > 0) {
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
        this.safeShowNotification(
          'error',
          error?.message || this.$t('KANBAN.ERRORS.DELETE_FAILED')
        );
      }
    },
    closeDeletePipelineModal() {
      this.showDeletePipelineModal = false;
    },
    // Método chamado quando o usuário clica em Editar no menu de ações
    editKanban() {
      if (!this.selectedAttribute) {
        this.safeShowNotification('error', this.$t('KANBAN.ERRORS.NO_PIPELINE_SELECTED'));
        return;
      }
      this.showEditPipelineModal = true;
    },

    // Método chamado quando o usuário clica em Excluir no menu de ações
    deleteKanban() {
      if (!this.selectedAttribute) {
        this.safeShowNotification('error', this.$t('KANBAN.ERRORS.NO_PIPELINE_SELECTED'));
        return;
      }
      this.showDeletePipelineModal = true;
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
}

.kanban-columns-container {
  flex: 1;
  overflow-x: auto;
  overflow-y: hidden;
  padding: var(--space-normal);
  
  &::-webkit-scrollbar {
    height: 8px;
  }
  
  &::-webkit-scrollbar-thumb {
    background-color: var(--s-200);
    border-radius: 4px;
    
    .dark-mode & {
      background-color: var(--b-600);
    }
  }
  
  &::-webkit-scrollbar-track {
    background-color: var(--s-75);
    border-radius: 4px;
    
    .dark-mode & {
      background-color: var(--b-700);
    }
  }
}

.kanban-columns {
  display: flex;
  gap: var(--space-normal);
  height: 100%;
  min-height: 200px;
  padding-bottom: var(--space-medium);
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
</style> 