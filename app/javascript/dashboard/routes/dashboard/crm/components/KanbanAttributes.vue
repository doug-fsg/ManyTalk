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
      :contacts="contacts"
      :pipeline-id="selectedAttribute ? selectedAttribute.id : null"
      :filters="kanbanFilters"
      :show-assignee-filter="isAdmin"
      @update:current-view="currentView = $event"
      @select-pipeline="selectPipeline"
      @search="handleSearch"
      @create-new="openCreateAttributeModal"
      @edit-kanban="editKanban"
      @delete-kanban="deleteKanban"
      @win-lost-filter="handleWinLostFilter"
      @filters-changed="handleFiltersChanged"
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

    <!-- Empty state quando não há pipelines kanban -->
    <kanban-empty-state
      v-if="!listTypeAttributes.length && !isLoadingInitialData"
      @create-pipeline="openCreateAttributeModal"
    />

    <!-- Loading state para o carregamento de contatos -->
    <woot-loading-state v-else-if="isLoadingContacts && selectedAttribute" :message="loadingMessage" />

    <!-- Dashboard View -->
    <kanban-dashboard
      v-else-if="currentView === 'dashboard' && selectedAttribute && !uiFlags.isFetching"
      :contacts="filteredContacts"
      :columns="displayColumns"
      :pipeline-id="selectedAttribute.id"
      :pipeline-name="selectedAttribute.attribute_display_name"
      @view-contact="openContact"
    />

    <!-- List View -->
    <div
      v-else-if="currentView === 'list' && selectedAttribute && !uiFlags.isFetching"
      class="list-view-container p-6 bg-slate-50 dark:bg-slate-900"
    >
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-soft border border-slate-200 dark:border-slate-700 hover:shadow-soft-lg transition-all duration-300 ease-smooth">
        <div class="p-4 border-b border-slate-200 dark:border-slate-700">
          <h2 class="text-xl font-semibold text-slate-900 dark:text-white">
            {{ $t('KANBAN.LIST_VIEW.TITLE') }}
          </h2>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-slate-50 dark:bg-slate-700/50">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                  {{ $t('KANBAN.LIST_VIEW.NAME') }}
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                  {{ $t('CONTACT_FORM.FORM.PHONE_NUMBER.LABEL') }}
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                  {{ $t('KANBAN.LIST_VIEW.STAGE') }}
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                  {{ $t('KANBAN.LIST_VIEW.VALUE') }}
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                  {{ $t('KANBAN.LIST_VIEW.TIME_IN_STAGE') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-200 dark:divide-slate-700">
              <tr
                v-for="contact in paginatedContacts"
                :key="contact.id"
                @click="handleOpenCardModal(contact)"
                class="cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors duration-150 ease-smooth"
              >
                <td class="px-4 py-3 whitespace-nowrap">
                  <div class="text-sm font-medium text-slate-900 dark:text-white">
                    {{ contact.name }}
                  </div>
                  <div v-if="contact.email" class="text-sm text-slate-500 dark:text-slate-400">
                    {{ contact.email }}
                  </div>
                </td>
                <td class="px-4 py-3 whitespace-nowrap">
                  <span v-if="contact.phone_number" class="text-sm text-slate-900 dark:text-white">
                    {{ contact.phone_number }}
                  </span>
                  <span v-else class="text-sm text-slate-400 dark:text-slate-500">
                    -
                  </span>
                </td>
                <td class="px-4 py-3 whitespace-nowrap">
                  <span class="text-sm text-slate-900 dark:text-white">
                    {{ getContactStage(contact) }}
                  </span>
                </td>
                <td class="px-4 py-3 whitespace-nowrap">
                  <span class="text-sm font-medium text-slate-900 dark:text-white">
                    {{ formatContactValue(contact) }}
                  </span>
                </td>
                <td class="px-4 py-3 whitespace-nowrap text-sm text-slate-500 dark:text-slate-400">
                  {{ getContactTimeInStage(contact) }}
                </td>
              </tr>
              <tr v-if="!filteredContacts.length">
                <td colspan="5" class="px-4 py-8 text-center text-slate-500 dark:text-slate-400">
                  {{ $t('KANBAN.LIST_VIEW.NO_CONTACTS') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        
        <!-- Paginação -->
        <div v-if="filteredContacts.length > 0 && totalListPages > 1" class="p-4 border-t border-slate-200 dark:border-slate-700 flex items-center justify-between">
          <div class="text-sm text-slate-600 dark:text-slate-400">
            Mostrando {{ (listCurrentPage - 1) * listItemsPerPage + 1 }} - {{ Math.min(listCurrentPage * listItemsPerPage, filteredContacts.length) }} de {{ totalListContacts }}
          </div>
          <div class="flex items-center gap-2">
            <button
              @click="loadListPage(listCurrentPage - 1)"
              :disabled="listCurrentPage === 1"
              class="px-3 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Anterior
            </button>
            <span class="text-sm text-slate-600 dark:text-slate-400">
              Página {{ listCurrentPage }} de {{ totalListPages }}
            </span>
            <button
              @click="loadListPage(listCurrentPage + 1)"
              :disabled="listCurrentPage === totalListPages"
              class="px-3 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Próxima
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Kanban View -->
    <div
      v-else-if="currentView === 'kanban' && selectedAttribute && !uiFlags.isFetching"
      class="kanban-board"
    >
      <div class="kanban-columns-container">
        <draggable
          v-model="columns"
          class="kanban-columns"
          :disabled="isColumnDragDisabled"
          :options="{
            group: 'columns',
            handle: '.column-header',
            animation: 150,
          }"
          @end="onColumnsReordered"
        >
          <kanban-column
            v-for="column in columns"
            :key="column.id"
            :column="getDisplayColumn(column)"
            :pipeline-id="selectedAttribute.id"
            :operation-manager="operationManager"
            :column-stats="columnStats[column.title]"
            :has-active-filters="hasActiveColumnFilters"
            :is-viewer-mode="isViewerMode"
            :allow-column-reorder="!isColumnDragDisabled"
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
            @open-card-modal="handleOpenCardModal"
            @assign-self-as-owner="handleAssignSelfAsOwner"
            @show-assign-owner-confirmation="handleShowAssignOwnerConfirmation"
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

    <!-- Modal de confirmação para virar responsável -->
    <woot-delete-modal
      :show.sync="showAssignOwnerModal"
      :on-close="closeAssignOwnerModal"
      :on-confirm="confirmAssignOwner"
      title="Virar responsável?"
      :message="assignOwnerModalMessage"
      confirm-text="Sim"
      reject-text="Não"
    />

    <!-- Modal de edição do pipeline -->
    <woot-modal
      :show.sync="showEditPipelineModal"
      :on-close="closeEditPipelineModal"
      size="medium"
      :full-width="false"
    >
      <edit-kanban-pipeline
        v-if="showEditPipelineModal"
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

    <!-- Kanban Card Detail Modal -->
    <kanban-card-modal
      v-if="showCardModal"
      :show="showCardModal"
      :contact="selectedCardContact"
      :pipeline-id="selectedAttribute ? selectedAttribute.id : null"
      :stage-color="getStageColor(getContactCurrentStage(selectedCardContact))"
      :available-stages="selectedAttribute ? selectedAttribute.attribute_values || [] : []"
      @close="handleCloseCardModal"
      @value-updated="handleDealValueUpdate"
      @stage-changed="handleStageChangeFromModal"
      @assignee-updated="handleAssigneeUpdated"
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
import KanbanDashboard from './KanbanDashboard.vue';
import EditKanbanPipeline from './EditKanbanPipeline.vue';
import CreateAttributeModal from './CreateAttributeModal.vue';
import WinLostModal from './WinLostModal.vue';
import AddContactToStageModal from './AddContactToStageModal.vue';
import KanbanCardModal from './KanbanCardModal.vue';
import KanbanEmptyState from './KanbanEmptyState.vue';
import { KanbanOperationManager } from '../utils/KanbanOperationManager';
import { PipelineCacheManager } from '../services/PipelineCacheManager';
import { KanbanLogger } from '../utils/KanbanLogger';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { getRandomColor } from 'dashboard/helper/labelColor';
import ContactAPI from 'dashboard/api/contacts';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import {
  getStage,
  getDealValue,
  getMetadata,
  getEnteredAt,
  getCreatedAt,
  getWinLostStatus
} from '../utils/pipelinePositionsHelper';

// Criar um barramento de eventos global compartilhado
if (!window.bus) {
  window.bus = new Vue();
}
const bus = window.bus;

export default {
  name: 'KanbanAttributes',
  components: {
    draggable,
    KanbanColumn,
    KanbanHeader,
    KanbanDashboard,
    EditKanbanPipeline,
    CreateAttributeModal,
    WinLostModal,
    AddContactToStageModal,
    KanbanCardModal,
    KanbanEmptyState,
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
      winLostFilter: 'open', // 'all', 'won', 'lost', 'open' - será sincronizado com kanbanFilters.winLost
      loadingProgress: null,
      loadingMessage: '',
      isLoadingInitialData: false,
      pagination: null,
      pipelineCacheManager: null,
      // Configuração de paginação para melhor performance
      initialLoadLimit: 100, // Limite inicial de contatos a carregar (usado apenas para carregamento incremental no Kanban)
      maxContactsToLoad: 5000, // Limite máximo de contatos (aumentado para suportar modo lista/dashboard com muitos contatos)
      contactsLoadedCount: 0,
      hasMoreContacts: false,
      // Estatísticas agregadas por coluna (totais reais do backend)
      columnStats: {}, // Formato: { [stageId]: { count: number, total_value: number } }
      showWinLostModal: false,
      winLostModalContact: {},
      winLostModalStatus: 'won',
      isSavingColumnOrder: false,
      winLostModalDealValue: 0,
      // Modal para adicionar contato na etapa
      showAddContactModal: false,
      selectedStageForContact: '',
      // Filtros do Kanban
      kanbanFilters: {
        labels: [],
        dealValueMin: null,
        dealValueMax: null,
        dateFrom: null,
        dateTo: null,
        assignees: [],
        winLost: 'open',
      },
      // Modal de detalhes do card
      showCardModal: false,
      selectedCardContact: {},
      // Paginação do modo lista
      listCurrentPage: 1,
      listItemsPerPage: 25,
      // Modal de atribuir dono
      showAssignOwnerModal: false,
      assignOwnerModalContact: null,
      assignOwnerModalCallbacks: null,
      assignOwnerModalMessage: '',
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
      this.bus.$on('contact_updated', this.handleContactUpdate);
      this.bus.$on('kanban_clear_updates', this.clearUpdateCache);
    }

    this.startCycleDetection();
    this.$el.addEventListener('scroll', this.updateScrollPosition);
    document.addEventListener('click', this.handleClickOutside);

    this.$nextTick(() => {
      this.updateTranslations();
    });
  },
  beforeDestroy() {
    clearTimeout(this.updateDebounceTimeout);
    clearTimeout(this.searchDebounce);
    clearTimeout(this.setupColumnsTimeout);

    if (this.bus) {
      this.bus.$off(BUS_EVENTS.THEME_CHANGE, this.checkDarkMode);
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
      canEditPipeline: 'kanban/canEditPipeline',
      canViewPipeline: 'kanban/canViewPipeline',
      getPipelinePermission: 'kanban/getPipelinePermission',
    }),
    isViewerMode() {
      if (!this.selectedAttribute) return false;
      const permission = this.getPipelinePermission(this.selectedAttribute.id);
      return permission === 'viewer';
    },
    canEditCurrentPipeline() {
      if (!this.selectedAttribute) return true;
      return this.canEditPipeline(this.selectedAttribute.id);
    },
    isDarkMode() {
      return this.$store.getters['theme/isDarkMode'];
    },
    listTypeAttributes() {
      // Filtrar apenas atributos marcados como Kanban
      const filteredAttrs = this.attributes.filter(attr => {
        // Se a coluna is_kanban existe, usar apenas ela para filtrar
        if (attr.hasOwnProperty('is_kanban')) {
          const isKanban = attr.is_kanban === true && attr.attribute_model === 'contact_attribute';
          
          // Se for pipeline Kanban, verificar permissão do usuário
          if (isKanban) {
            // Se can_view está definido na resposta da API, usar ele (mais confiável)
            if (attr.hasOwnProperty('can_view')) {
              return attr.can_view === true;
            }
            // Se user_permission está definido, verificar se não é 'none'
            if (attr.hasOwnProperty('user_permission')) {
              return attr.user_permission !== 'none';
            }
            // Se não tem informação de permissão (versões antigas sem sistema de permissões)
            // Apenas admins podem ver (comportamento padrão seguro)
            if (this.currentUser && this.currentUser.role === 'administrator') {
              return true;
            }
            // Para não-admins sem informação de permissão, não mostrar (segurança por padrão)
            return false;
          }
          
          return false;
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
    hasActiveColumnFilters() {
      const hasSearch = !!(this.searchQuery && this.searchQuery.trim());
      const hasWinLost = this.winLostFilter && this.winLostFilter !== 'open';
      const filters = this.kanbanFilters || {};
      const hasLabels = filters.labels && filters.labels.length > 0;
      const hasDealValue =
        (filters.dealValueMin !== null && filters.dealValueMin !== '') ||
        (filters.dealValueMax !== null && filters.dealValueMax !== '');
      const hasDateRange = filters.dateFrom || filters.dateTo;
      const hasAssignees = filters.assignees && filters.assignees.length > 0;

      return (
        hasSearch ||
        hasWinLost ||
        hasLabels ||
        hasDealValue ||
        hasDateRange ||
        hasAssignees
      );
    },
    isColumnDragDisabled() {
      return (
        this.isViewerMode ||
        !this.canEditCurrentPipeline ||
        this.hasActiveColumnFilters ||
        this.isSavingColumnOrder
      );
    },
    displayColumns() {
      if (this.hasActiveColumnFilters && this.filteredColumns.length) {
        return this.filteredColumns;
      }
      return this.columns;
    },
    // Contatos paginados para o modo lista (já vem paginado do backend)
    paginatedContacts() {
      if (this.currentView !== 'list') {
        return this.filteredContacts;
      }
      // No modo lista, filteredContacts já contém apenas os contatos da página atual
      return this.filteredContacts;
    },
    // Total de páginas para o modo lista (calculado pelo backend)
    totalListPages() {
      if (this.currentView !== 'list') {
        return 1;
      }
      // Usar meta do store se disponível, senão calcular baseado nos contatos carregados
      const meta = this.$store.getters['contacts/getMeta'];
      if (meta && meta.total_pages) {
        return meta.total_pages;
      }
      // Fallback: calcular baseado nos contatos carregados
      return Math.ceil(this.filteredContacts.length / this.listItemsPerPage);
    },
    // Total de contatos no modo lista (do backend)
    totalListContacts() {
      if (this.currentView !== 'list') {
        return this.filteredContacts.length;
      }
      const meta = this.$store.getters['contacts/getMeta'];
      if (meta && meta.count) {
        return meta.count;
      }
      return this.filteredContacts.length;
    },
    // Contatos filtrados para usar no Dashboard e List View
    filteredContacts() {
      // Aplicar os mesmos filtros que são aplicados nas colunas
      const searchQuery = (this.searchQuery || '').toLowerCase();
      const filtered = this.contacts.filter(contact => {
        // Search filter
        let matchesSearch = true;
        if (searchQuery && searchQuery.trim() !== '') {
          const name = (contact.name || '').toLowerCase();
          const email = (contact.email || '').toLowerCase();
          const phone = (contact.phone_number || '').toLowerCase();

          matchesSearch = (
            name.includes(searchQuery) ||
            email.includes(searchQuery) ||
            phone.includes(searchQuery)
          );
        }

        // Win/Lost filter usando pipeline_positions
        let matchesWinLost = true;
        if (this.winLostFilter && this.winLostFilter !== 'all' && this.selectedAttribute) {
          const winLostData = getWinLostStatus(contact, this.selectedAttribute.id);
          const winLostStatus = winLostData?.status;
          
          if (this.winLostFilter === 'won') {
            matchesWinLost = winLostStatus === 'won';
          } else if (this.winLostFilter === 'lost') {
            matchesWinLost = winLostStatus === 'lost';
          } else if (this.winLostFilter === 'open') {
            matchesWinLost = !winLostStatus || winLostStatus === null || winLostStatus === undefined;
          }
        }

        // Labels filter
        let matchesLabels = true;
        if (this.kanbanFilters.labels && this.kanbanFilters.labels.length > 0) {
          const contactLabels = (contact.labels || []).map(l => l.id);
          matchesLabels = this.kanbanFilters.labels.some(labelId => 
            contactLabels.includes(labelId)
          );
        }

        // Deal Value filter usando pipeline_positions
        let matchesDealValue = true;
        if (this.selectedAttribute) {
          const dealValue = getDealValue(contact, this.selectedAttribute.id) || 0;
          if (this.kanbanFilters.dealValueMin !== null && this.kanbanFilters.dealValueMin !== '') {
            matchesDealValue = matchesDealValue && dealValue >= parseFloat(this.kanbanFilters.dealValueMin);
          }
          if (this.kanbanFilters.dealValueMax !== null && this.kanbanFilters.dealValueMax !== '') {
            matchesDealValue = matchesDealValue && dealValue <= parseFloat(this.kanbanFilters.dealValueMax);
          }
        }

        // Date Range filter usando created_at de contact_pipeline_positions
        let matchesDateRange = true;
        if (this.kanbanFilters.dateFrom || this.kanbanFilters.dateTo) {
          if (!this.selectedAttribute) {
            matchesDateRange = false;
          } else {
            // Usar created_at da position do pipeline (quando o card foi criado no pipeline)
            const createdAt = getCreatedAt(contact, this.selectedAttribute.id);
            if (!createdAt) {
              matchesDateRange = false;
            } else {
              const createdDate = new Date(createdAt); // created_at vem como ISO string
              
              if (this.kanbanFilters.dateFrom) {
                const fromDate = new Date(this.kanbanFilters.dateFrom);
                fromDate.setHours(0, 0, 0, 0);
                matchesDateRange = matchesDateRange && createdDate >= fromDate;
              }
              if (this.kanbanFilters.dateTo) {
                const toDate = new Date(this.kanbanFilters.dateTo);
                // Para dateTo, queremos incluir o dia inteiro até 23:59:59.999
                toDate.setHours(23, 59, 59, 999);
                matchesDateRange = matchesDateRange && createdDate <= toDate;
              }
            }
          }
        }

        // Assignee filter usando pipeline_positions
        let matchesAssignee = true;
        if (this.kanbanFilters.assignees && this.kanbanFilters.assignees.length > 0 && this.selectedAttribute) {
          const position = contact.pipeline_positions?.find(
            p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
          );
          const assigneeId = position?.assignee?.id || null;
          const selectedIds = this.kanbanFilters.assignees.map(a => a.id);
          matchesAssignee = selectedIds.includes(assigneeId) || (selectedIds.includes(null) && assigneeId === null);
        }

        return matchesSearch && matchesWinLost && matchesLabels && matchesDealValue && matchesDateRange && matchesAssignee;
      });

      return filtered;
    },
    currentUser() {
      return this.$store.getters.getCurrentUser;
    },
    isAdmin() {
      // Verifica se o usuário atual é administrador global
      if (this.currentUser && this.currentUser.role === 'administrator') {
        return true;
      }
      // Verifica se o usuário tem permissão de supervisor no pipeline atual
      if (this.selectedAttribute) {
        const permission = this.getPipelinePermission(this.selectedAttribute.id);
        return permission === 'supervisor' || permission === 'admin';
      }
      return false;
    },
    // Otimização: Criar índice de contatos por coluna uma vez, evitando refazer filtros
    // Agora usa pipeline_positions em vez de custom_attributes
    contactsByColumn() {
      if (!this.selectedAttribute || !this.contacts || this.contacts.length === 0) {
        return {};
      }

      const index = {};
      const pipelineId = this.selectedAttribute.id;
      const currentUserId = this.currentUser?.id;

      // Criar índice uma vez: mapear cada valor de etapa para array de contatos
      // Usa pipeline_positions em vez de custom_attributes
      // Filtrar por assignee: não-admin vê apenas seus cards ou cards sem dono
      this.contacts.forEach(contact => {
        if (!contact.pipeline_positions || !Array.isArray(contact.pipeline_positions)) {
          return;
        }

        const position = contact.pipeline_positions.find(
          p => p.pipeline_id === pipelineId || p.pipeline_id === parseInt(pipelineId, 10)
        );

        // Filtrar por visibilidade: admin vê tudo, outros veem apenas seus cards ou sem dono
        if (!this.isAdmin && position) {
          const assigneeId = position.assignee?.id || null;
          if (assigneeId !== null && assigneeId !== currentUserId) {
            return; // Não mostrar card de outro usuário
          }
        }

        const stageId = getStage(contact, pipelineId);
        if (stageId) {
          if (!index[stageId]) {
            index[stageId] = [];
          }
          index[stageId].push(contact);
        }
      });

      return index;
    },

  },
  watch: {
    // Resetar página ao mudar de view
    currentView(newView) {
      if (newView !== 'list') {
        this.listCurrentPage = 1;
      }
    },
    // Otimização: Remover watcher genérico de contacts que causa loops
    // Em vez disso, usar watchers específicos ou atualizações manuais quando necessário
    // O watcher genérico causava setupColumns() toda vez que getContacts retornava novo array
    // mesmo sem mudanças reais nos dados
    // Observar mudanças na query de busca
    searchQuery: {
      handler(newVal) {
        if (this.currentView === 'list' && this.selectedAttribute) {
          // No modo lista, recarregar contatos da API
          this.listCurrentPage = 1;
          this.loadContactsPage(1);
        } else {
          // No modo kanban, usar filtro local
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
    },
    async loadInitialData() {
      try {
        this.isLoadingInitialData = true; // Definir flag como true no início

        await this.fetchAttributes();
        if (this.listTypeAttributes.length > 0) {
          // Always select the first pipeline if none is selected
          if (!this.selectedAttribute) {
            this.selectedAttribute = this.listTypeAttributes[0];
            this.saveSelectedPipeline(this.selectedAttribute.id);
          }
          await this.fetchContacts();
          this.setupColumns();
        }
        // Se não há pipelines kanban, a tela vazia será mostrada automaticamente
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

    async updateCardPosition(contact, newColumn, operationId) {
      const previousColumn = this.getCurrentColumn(contact.id);

      // Atualizar UI primeiro (otimista)
      this.updateColumnsLocally(contact, newColumn);

      try {
        // Atualizar no servidor usando pipeline_positions
        if (this.selectedAttribute) {
          // Obter dados atuais do pipeline_positions
          const currentPosition = contact.pipeline_positions?.find(
            p => p.pipeline_id === this.selectedAttribute.id
          );
          
          const now = new Date().toISOString();
          const dealValue = currentPosition?.deal_value;
          const metadata = currentPosition?.metadata || {};
          const position = currentPosition?.position || 0;

          // Atualizar via pipeline_positions (mantém assignee atual)
          const response = await ContactAPI.updatePipelinePosition(
            contact.id,
            this.selectedAttribute.id,
            newColumn,
            position,
            now,
            dealValue,
            metadata
            // Não passar options - mantém assignee atual
          );

          // Atualizar pipeline_positions localmente
          if (contact.pipeline_positions) {
            const positionIndex = contact.pipeline_positions.findIndex(
              p => p.pipeline_id === this.selectedAttribute.id
            );
            
            const updatedPosition = {
              pipeline_id: response.data.pipeline_id,
              stage_id: response.data.stage_id,
              position: response.data.position,
              entered_at: response.data.entered_at,
              deal_value: response.data.deal_value,
              metadata: response.data.metadata || {},
              assignee: response.data.assignee || null,
            };
            
            if (positionIndex >= 0) {
              this.$set(contact.pipeline_positions, positionIndex, updatedPosition);
            } else {
              contact.pipeline_positions.push(updatedPosition);
            }
          }

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

    updateContactStageLocally(contact, newColumn) {
      // Apenas atualiza pipeline_positions - o vuedraggable já moveu o card nas colunas
      if (contact.pipeline_positions && this.selectedAttribute) {
        const position = contact.pipeline_positions.find(
          p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
        );
        if (position) {
          this.$set(position, 'stage_id', newColumn);
        }
      }
    },

    updateColumnsLocally(contact, newColumn, newIndex = null) {
      // Usado apenas para REVERTER em caso de erro da API
      this.columns.forEach(column => {
        const index = column.items.findIndex(item => item.id === contact.id);
        if (index !== -1) {
          column.items.splice(index, 1);
        }
      });

      if (contact.pipeline_positions && this.selectedAttribute) {
        const position = contact.pipeline_positions.find(
          p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
        );
        if (position) {
          this.$set(position, 'stage_id', newColumn);
        }
      }

      const targetColumn = this.columns.find(col => col.title === newColumn);
      if (targetColumn) {
        if (newIndex !== null && newIndex >= 0 && newIndex <= targetColumn.items.length) {
          targetColumn.items.splice(newIndex, 0, contact);
        } else {
          targetColumn.items.push(contact);
        }
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

    applyFiltersToColumns() {
      if (!this.hasActiveColumnFilters) {
        this.filteredColumns = [];
        return;
      }

      const searchQuery = (this.searchQuery || '').toLowerCase();
      this.filteredColumns = this.columns.map(column => {
        const filteredItems = column.items.filter(contact => {
          let matchesSearch = true;
          if (searchQuery && searchQuery.trim() !== '') {
            const name = (contact.name || '').toLowerCase();
            const email = (contact.email || '').toLowerCase();
            const phone = (contact.phone_number || '').toLowerCase();
            matchesSearch = (
              name.includes(searchQuery) ||
              email.includes(searchQuery) ||
              phone.includes(searchQuery)
            );
          }

          let matchesWinLost = true;
          if (this.winLostFilter && this.winLostFilter !== 'all' && this.selectedAttribute) {
            const winLostData = getWinLostStatus(contact, this.selectedAttribute.id);
            const winLostStatus = winLostData?.status;
            if (this.winLostFilter === 'won') matchesWinLost = winLostStatus === 'won';
            else if (this.winLostFilter === 'lost') matchesWinLost = winLostStatus === 'lost';
            else if (this.winLostFilter === 'open') {
              matchesWinLost = !winLostStatus || winLostStatus === null || winLostStatus === undefined;
            }
          }

          let matchesLabels = true;
          if (this.kanbanFilters.labels && this.kanbanFilters.labels.length > 0) {
            const contactLabels = (contact.labels || []).map(l => l.id);
            matchesLabels = this.kanbanFilters.labels.some(labelId => contactLabels.includes(labelId));
          }

          let matchesDealValue = true;
          if (this.selectedAttribute) {
            const dealValue = getDealValue(contact, this.selectedAttribute.id) || 0;
            if (this.kanbanFilters.dealValueMin !== null && this.kanbanFilters.dealValueMin !== '') {
              matchesDealValue = matchesDealValue && dealValue >= parseFloat(this.kanbanFilters.dealValueMin);
            }
            if (this.kanbanFilters.dealValueMax !== null && this.kanbanFilters.dealValueMax !== '') {
              matchesDealValue = matchesDealValue && dealValue <= parseFloat(this.kanbanFilters.dealValueMax);
            }
          }

          let matchesDateRange = true;
          if (this.kanbanFilters.dateFrom || this.kanbanFilters.dateTo) {
            if (!this.selectedAttribute) matchesDateRange = false;
            else {
              const createdAt = getCreatedAt(contact, this.selectedAttribute.id);
              if (!createdAt) matchesDateRange = false;
              else {
                const createdDate = new Date(createdAt);
                if (this.kanbanFilters.dateFrom) {
                  const fromDate = new Date(this.kanbanFilters.dateFrom);
                  fromDate.setHours(0, 0, 0, 0);
                  matchesDateRange = matchesDateRange && createdDate >= fromDate;
                }
                if (this.kanbanFilters.dateTo) {
                  const toDate = new Date(this.kanbanFilters.dateTo);
                  toDate.setHours(23, 59, 59, 999);
                  matchesDateRange = matchesDateRange && createdDate <= toDate;
                }
              }
            }
          }

          let matchesAssignee = true;
          if (this.kanbanFilters.assignees && this.kanbanFilters.assignees.length > 0 && this.selectedAttribute) {
            const position = contact.pipeline_positions?.find(
              p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
            );
            const assigneeId = position?.assignee?.id || null;
            const selectedIds = this.kanbanFilters.assignees.map(a => a.id);
            matchesAssignee = selectedIds.includes(assigneeId) || (selectedIds.includes(null) && assigneeId === null);
          }

          return matchesSearch && matchesWinLost && matchesLabels && matchesDealValue && matchesDateRange && matchesAssignee;
        });
        return { ...column, items: filteredItems };
      });
    },

    handleSearch(query) {
      if (query !== undefined) this.searchQuery = query;
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(() => this.applyFiltersToColumns(), 300);
    },

    async fetchAttributes() {
      try {
        await this.$store.dispatch('attributes/get');

        // Forçar atualização se houver atributos válidos
        if (this.listTypeAttributes.length > 0 && !this.selectedAttribute) {
          // Tentar restaurar pipeline salvo
          const savedPipelineId = this.getSavedPipelineId();
          if (savedPipelineId) {
            const savedAttribute = this.listTypeAttributes.find(
              attr => attr.id === parseInt(savedPipelineId, 10)
            );
            if (savedAttribute) {
              this.selectedAttribute = savedAttribute;
              this.fetchContacts();
              return;
            } else {
              // Pipeline salvo não existe mais, limpar do localStorage
              this.clearSavedPipeline();
            }
          }
          // Usar defaultAttribute como fallback
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

        // PRIMEIRO: Carregar estatísticas agregadas (totais reais) do backend
        // Isso permite que os totais apareçam imediatamente no cabeçalho das colunas
        await this.fetchColumnStats();

        // Configurar colunas vazias com os totais já disponíveis
        this.setupColumns();

        // SEGUNDO: Carregar contatos
        // No modo lista: carregar apenas uma página (performance)
        // No modo kanban: carregar todos os contatos
        if (this.currentView === 'list') {
          await this.loadContactsPage(1);
          // Carregar atividades dos contatos carregados de forma não-bloqueante
          this.loadAllActivities().catch(err => {
            console.debug('[KanbanAttributes] Activities loading failed', err);
          });
        } else {
          await this.loadAllContacts();
          // Atualizar colunas com os contatos carregados
          this.setupColumns();
          // Carregar atividades de forma não-bloqueante após renderização
          // Usar nextTick para garantir que os cards já renderizaram
          this.$nextTick(() => {
            this.loadAllActivities().catch(err => {
              console.debug('[KanbanAttributes] Activities loading failed', err);
            });
          });
        }
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
        this.contactsLoadedCount = 0;
        this.hasMoreContacts = false;

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

        // Per page maior para Kanban (100 vs 15) - reduz requisições de ~334 para ~50
        const kanbanPerPage = 100;
        const loadContactsPage = async page => {
          try {
            const contacts = await this.$store.dispatch('contacts/filter', {
              page,
              queryPayload,
              resetState: false,
              perPage: kanbanPerPage,
            });
            return contacts || [];
          } catch (error) {
            return [];
          }
        };
        
        // Expor método para carregar uma página (usado no modo lista)
        this.loadContactsPage = async (page = 1) => {
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
          
          const contacts = await this.$store.dispatch('contacts/filter', {
            page,
            queryPayload,
            resetState: page === 1,
          });
          
          return contacts || [];
        };

        // Carregar até 3 páginas em paralelo para reduzir tempo total
        const parallelPages = 3;
        const loadNextBatch = async startPage => {
          const pagesToLoad = [];
          for (let p = 0; p < parallelPages; p++) {
            const pageNum = startPage + p;
            if (totalContactsLoaded >= this.maxContactsToLoad) break;
            pagesToLoad.push(pageNum);
          }

          const results = await Promise.all(
            pagesToLoad.map(p => loadContactsPage(p))
          );

          let lastLoadedPage = startPage - 1;
          let hasMore = true;

          for (let i = 0; i < results.length; i++) {
            const contacts = results[i];
            const pageNum = pagesToLoad[i];

            if (!contacts || contacts.length === 0) {
              hasMore = false;
              break;
            }

            const newContacts = contacts.filter(
              c => !existingContacts.some(existing => existing.id === c.id)
            );

            if (newContacts.length > 0) {
              const remainingSlots = this.maxContactsToLoad - totalContactsLoaded;
              const contactsToAdd = remainingSlots > 0
                ? newContacts.slice(0, remainingSlots)
                : [];

              if (contactsToAdd.length > 0) {
                existingContacts.push(...contactsToAdd);
                this.$store.commit('contacts/SET_CONTACTS', existingContacts);
                totalContactsLoaded += contactsToAdd.length;
                this.contactsLoadedCount = totalContactsLoaded;
              }
            }

            lastLoadedPage = pageNum;
            if (contacts.length < kanbanPerPage) {
              hasMore = false;
              break;
            }
            if (totalContactsLoaded >= this.maxContactsToLoad) break;
          }

          return { lastPage: lastLoadedPage, hasMore };
        };

        let result = { lastPage: 0, hasMore: false };
        let batchStart = 1;
        while (batchStart <= 1000) {
          result = await loadNextBatch(batchStart);
          if (totalContactsLoaded >= this.maxContactsToLoad) {
            this.hasMoreContacts = true;
            break;
          }
          if (!result.hasMore) break;
          batchStart = result.lastPage + 1;
        }

        // Atualizar o cache do pipeline
        this.pipelineCacheManager.updateCache(this.selectedAttribute.id, {
          currentPage: result.lastPage,
          totalPages: Math.ceil(totalContactsLoaded / kanbanPerPage),
          hasMore: result.hasMore || this.hasMoreContacts,
          isLoadingMore: false,
        });

        // Carregar atividades pendentes de todos os contatos carregados de forma não-bloqueante
        this.loadAllActivities().catch(err => {
          console.debug('[KanbanAttributes] Activities loading failed', err);
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
    async loadAllActivities() {
      try {
        const contacts = this.contacts || [];
        if (!Array.isArray(contacts) || contacts.length === 0) return;

        const contactIds = contacts.map(c => c.id).filter(id => id != null);
        if (contactIds.length === 0) return;

        // Requisições em lote: 100 contatos por request (em vez de 1 por contato)
        const batchSize = 100;
        const batches = [];
        for (let i = 0; i < contactIds.length; i += batchSize) {
          batches.push(contactIds.slice(i, i + batchSize));
        }

        for (let i = 0; i < batches.length; i++) {
          try {
            await this.$store.dispatch('activities/get', {
              accountId: this.$route.params.accountId,
              params: { contact_ids: batches[i], status: 'pending' },
              merge: i > 0,
            });
          } catch (error) {
            if (i === 0) {
              this.$store.commit('activities/SET_ACTIVITIES', []);
            }
          }
        }
      } catch (error) {
        this.$store.commit('activities/SET_ACTIVITIES', []);
      }
    },
    selectAttribute(attribute) {
      this.selectedAttribute = attribute;
      this.saveSelectedPipeline(attribute.id);
    },
    async fetchColumnStats() {
      if (!this.selectedAttribute) return;

      try {
        const response = await ContactAPI.getPipelineStats(this.selectedAttribute.id);
        
        if (response.data && response.data.stage_stats) {
          // Converter array de stage_stats em objeto indexado por stage_id
          const statsMap = {};
          response.data.stage_stats.forEach(stage => {
            statsMap[stage.stage_id] = {
              count: stage.count,
              total_value: stage.total_value || 0
            };
          });
          
          this.columnStats = statsMap;
        }
      } catch (error) {
        // Fallback para cálculo local se a API falhar
        this.columnStats = {};
      }
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

      this.columns = [];
      const attributeValues = this.selectedAttribute.attribute_values;
      
      // Garantir que values seja sempre um array
      const values = Array.isArray(attributeValues) ? attributeValues : [];
      
      // Se não for array válido, retornar sem criar colunas
      if (values.length === 0) {
        return;
      }

      // PRIMEIRO: Carregar todas as cores do backend no colorMap
      values.forEach((value) => {
        let stageName;
        let stageColor = null;
        
        if (typeof value === 'object' && value !== null) {
          stageName = value.name || value.value || String(value);
          stageColor = value.color || null;
        } else {
          stageName = String(value);
        }
        
        // Carregar cor salva no colorMap se disponível
        if (stageColor) {
          this.colorMap[stageName] = stageColor;
        }
      });

      // SEGUNDO: Criar colunas a partir dos valores de atributos
      // Otimização: usar índice contactsByColumn em vez de filtrar toda vez
      values.forEach((value, index) => {
        // Extrair nome do valor (pode ser string ou objeto)
        let stageName;
        
        if (typeof value === 'object' && value !== null) {
          stageName = value.name || value.value || String(value);
        } else {
          stageName = String(value);
        }
        
        // Usar uma cor consistente para cada valor (já carregada no colorMap acima)
        const color = this.getStageColor(stageName);
        // Usar índice pré-calculado em vez de filtrar todos os contatos
        let contacts = this.contactsByColumn[stageName] || [];

        // Ordenar por position quando disponível (vindo de contact_pipeline_positions)
        // Se não tiver position, manter ordem atual (que já reflete ordem do drag)
        contacts = [...contacts].sort((a, b) => {
          const posA = this.getContactPosition(a.id, this.selectedAttribute.id, stageName);
          const posB = this.getContactPosition(b.id, this.selectedAttribute.id, stageName);
          
          // Se ambos têm position, ordenar por position
          if (posA !== null && posB !== null && posA !== undefined && posB !== undefined) {
            return posA - posB;
          }
          
          // Se apenas um tem position, ele vem primeiro
          if (posA !== null && posA !== undefined) return -1;
          if (posB !== null && posB !== undefined) return 1;
          
          // Se nenhum tem position, manter ordem atual (created_at ou ordem de inserção)
          // Mas ordenar por created_at como fallback para consistência
          const createdA = a.created_at || 0;
          const createdB = b.created_at || 0;
          return createdA - createdB;
        });

        this.columns.push({
          id: `column-${stageName}`,
          title: stageName,
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

      const pipelineId = this.selectedAttribute.id;

      return this.contacts.filter(contact => {
        // Garantir que cada contato tenha propriedades básicas
        if (!contact.labels) {
          contact.labels = [];
        }

        // Usar pipeline_positions em vez de custom_attributes
        const stageId = getStage(contact, pipelineId);
        return stageId === columnValue;
      });
    },
    async onItemMoved({ contactId, sourceColumnTitle, targetColumnTitle, oldIndex, newIndex }) {
      // Verificar permissão de edição
      if (this.isViewerMode) {
        this.$store.dispatch('notifications/show', {
          message: this.$t('KANBAN.ERRORS.VIEWER_CANNOT_MOVE'),
          type: 'error',
        });
        return;
      }

      // Verificar se o contato existe
      const contact = this.contacts.find(c => c.id === contactId);
      if (!contact) {
        return;
      }

      // Verificar permissão para mover este card específico
      if (!this.isAdmin && !this.isViewerMode) {
        // Editor: só pode mover cards próprios ou sem dono
        const currentPosition = contact.pipeline_positions?.find(
          p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
        );
        const cardAssigneeId = currentPosition?.assignee?.id || null;
        const currentUserId = this.currentUser?.id;

        if (cardAssigneeId && cardAssigneeId !== currentUserId) {
          // Card tem dono e não é o usuário atual
          this.$store.dispatch('notifications/show', {
            message: this.$t('KANBAN.ERRORS.CANNOT_MOVE_CARD'),
            type: 'error',
          });
          // Reverter movimento visual
          this.setupColumns();
          return;
        }
      }

      // ============================================
      // FASE 1: ATUALIZAÇÃO OTIMISTA (sem tocar nas colunas)
      // ============================================
      // O vuedraggable já moveu o card via handleColumnItemsUpdate - NÃO refazer
      // Apenas atualizar contact.pipeline_positions para manter dados consistentes
      this.updateContactStageLocally(contact, targetColumnTitle);

      // Obter deal_value e metadata existentes do pipeline_positions
      const currentPosition = contact.pipeline_positions?.find(
        p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
      );
      const currentDealValue = currentPosition?.deal_value;
      const currentMetadata = currentPosition?.metadata || {};

      // ============================================
      // FASE 2: ATUALIZAR APENAS contact_pipeline_positions
      // ============================================
      // NÃO atualizar tabela contacts - apenas contact_pipeline_positions
      // Isso é muito mais rápido e não bloqueia a UI
      
      // IMPORTANTE: Não enviar assignee_id ao mover card
      // O backend só permite trocar dono se for admin
      // Ao mover, queremos manter o dono atual, então não enviamos assignee_id
      ContactAPI.updatePipelinePosition(
        contactId,
        this.selectedAttribute.id,
        targetColumnTitle,
        newIndex,
        new Date().toISOString(),
        currentDealValue,
        currentMetadata
        // Não passar options - mantém assignee atual
      )
        .then(async (response) => {
          // Atualizar o contato no store com os dados de pipeline_positions retornados
          const updatedContact = this.contacts.find(c => c.id === contactId);
          if (updatedContact && response.data) {
            // Atualizar ou criar pipeline_positions no contato
            if (!updatedContact.pipeline_positions) {
              this.$set(updatedContact, 'pipeline_positions', []);
            }
            
            // Encontrar ou criar a entrada de pipeline_position
            const positionIndex = updatedContact.pipeline_positions.findIndex(
              p => p.pipeline_id === this.selectedAttribute.id
            );
            
            // Backend sempre envia assignee (null quando não tem), então usar diretamente
            const positionData = {
              pipeline_id: response.data.pipeline_id,
              stage_id: response.data.stage_id,
              position: response.data.position,
              entered_at: response.data.entered_at,
              deal_value: response.data.deal_value,
              metadata: response.data.metadata || {},
              assignee: response.data.assignee || null, // Backend sempre envia
            };
            
            if (positionIndex >= 0) {
              this.$set(updatedContact.pipeline_positions, positionIndex, positionData);
            } else {
              updatedContact.pipeline_positions.push(positionData);
            }
          }
          
          // Mostrar notificação de sucesso
          this.safeShowNotification('success', this.$t('KANBAN.SUCCESS.CARD_MOVED'));
          
          // NÃO chamar setupColumns - o card já está na coluna correta (update otimista)
          // Reconstruir colunas causaria "piscar" e voltar o card para a origem
          // Atualizar stats em background
          this.fetchColumnStats();
          })
          .catch(error => {
            // Se a API falhar, reverter a mudança local
            this.revertLocalUpdate(contact, sourceColumnTitle);
            
            // Verificar se é erro de permissão (403) e mostrar mensagem específica
            if (error?.response?.status === 403) {
              // Verificar se é erro de viewer ou outro tipo de permissão
              const errorMessage = error?.response?.data?.error || '';
              if (this.isViewerMode || errorMessage.includes('permissão') || errorMessage.includes('permission')) {
                useAlert(this.$t('KANBAN.ERRORS.VIEWER_CANNOT_MOVE'));
              } else {
                useAlert(errorMessage || this.$t('KANBAN.ERRORS.UPDATE_FAILED'));
              }
            } else {
              useAlert(this.$t('KANBAN.ERRORS.UPDATE_FAILED'));
            }
        });
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
        this.saveSelectedPipeline(newAttribute.id);
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
      // Primeiro, verificar se já existe no colorMap (já carregado)
      if (this.colorMap[stageName]) {
        return this.colorMap[stageName];
      }
      
      // Se não está no colorMap, verificar se há cor salva no selectedAttribute
      if (this.selectedAttribute && this.selectedAttribute.attribute_values) {
        const attributeValues = this.selectedAttribute.attribute_values;
        if (Array.isArray(attributeValues)) {
          const stageWithColor = attributeValues.find(stage => {
            if (typeof stage === 'object' && stage !== null) {
              return (stage.name || stage.value) === stageName;
            }
            return stage === stageName;
          });
          
          if (stageWithColor && typeof stageWithColor === 'object' && stageWithColor.color) {
            this.colorMap[stageName] = stageWithColor.color;
            return stageWithColor.color;
          }
        }
      }
      
      // Se não encontrou cor salva, gerar uma nova
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

        // Remover do pipeline usando API de pipeline_positions
        await ContactAPI.deletePipelinePosition(contact.id, this.selectedAttribute.id);
        
        // Atualizar localmente removendo da lista de pipeline_positions
        if (contact.pipeline_positions) {
          const positionIndex = contact.pipeline_positions.findIndex(
            p => p.pipeline_id === this.selectedAttribute.id
          );
          if (positionIndex >= 0) {
            contact.pipeline_positions.splice(positionIndex, 1);
            this.$set(contact, 'pipeline_positions', contact.pipeline_positions);
          }
        }
        
        // Reconstruir colunas após remoção
        this.setupColumns();

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
      // Ignorar atualizações que vieram do Kanban
      if (payload?.fromKanban || payload?.kanbanOperation) return;
      
      // Se não há atributo selecionado, não há o que atualizar
      if (!this.selectedAttribute) return;

      // Aguardar próximo tick para garantir que Vue processou a atualização do store
      // Isso é necessário para que contactsByColumn recalcule com os dados atualizados
      this.$nextTick(() => {
        // Resetar throttle para permitir atualização imediata
        this.lastColumnUpdateTime = 0;
        clearTimeout(this.setupColumnsTimeout);
        this.setupColumns();
      });
    },
    // Helper para obter position do contato no pipeline
    getContactPosition(contactId, pipelineId, stageId) {
      const contact = this.contacts.find(c => c.id === contactId);
      if (!contact) {
        return null;
      }
      
      // Se não tem pipeline_positions, retornar null
      if (!contact.pipeline_positions || !Array.isArray(contact.pipeline_positions)) {
        return null;
      }
      
      // Converter pipelineId para número se necessário (pode vir como string)
      const pipelineIdNum = typeof pipelineId === 'string' ? parseInt(pipelineId, 10) : pipelineId;
      
      const position = contact.pipeline_positions.find(
        p => {
          const pPipelineId = typeof p.pipeline_id === 'string' ? parseInt(p.pipeline_id, 10) : p.pipeline_id;
          return pPipelineId === pipelineIdNum && p.stage_id === stageId;
        }
      );
      
      if (!position) {
        return null;
      }
      
      // Retornar position como número
      const pos = typeof position.position === 'string' ? parseInt(position.position, 10) : position.position;
      return pos !== null && pos !== undefined ? pos : null;
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
        this.$set(this.columns[columnIndex], 'items', items);
        // Sincronizar filteredColumns imediatamente para evitar "voltar" visual
        if (this.hasActiveColumnFilters) {
          this.applyFiltersToColumns();
        }
      }
    },
    getDisplayColumn(column) {
      if (!this.hasActiveColumnFilters) {
        return column;
      }

      const filteredColumn = this.filteredColumns.find(
        col => col.id === column.id || col.title === column.title
      );
      return filteredColumn || column;
    },
    buildAttributeValuesFromColumns() {
      const stages = {};
      const stageOrder = [];

      this.columns.forEach(column => {
        stages[column.title] = {
          color: column.color || this.getStageColor(column.title),
        };
        stageOrder.push(column.title);
      });

      const permissions = this.selectedAttribute?.permissions
        ? { ...this.selectedAttribute.permissions }
        : {};

      return {
        stages,
        stage_order: stageOrder,
        permissions,
      };
    },
    async onColumnsReordered(event) {
      if (this.isColumnDragDisabled) return;
      if (event.oldIndex === event.newIndex) return;
      if (!this.selectedAttribute) return;

      this.isSavingColumnOrder = true;

      try {
        await this.$store.dispatch('attributes/update', {
          id: this.selectedAttribute.id,
          attribute_values: this.buildAttributeValuesFromColumns(),
        });

        const updatedStages = this.columns.map(column => ({
          name: column.title,
          color: column.color || this.getStageColor(column.title),
        }));

        this.$set(this.selectedAttribute, 'attribute_values', updatedStages);

        if (window.bus) {
          window.bus.$emit('attributes:updated');
        }
      } catch (error) {
        this.setupColumns();
        this.safeShowNotification(
          'error',
          error?.message || this.$t('KANBAN.ERRORS.UPDATE_FAILED')
        );
      } finally {
        this.isSavingColumnOrder = false;
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
    // Métodos para persistência do pipeline selecionado
    saveSelectedPipeline(pipelineId) {
      try {
        localStorage.setItem(LOCAL_STORAGE_KEYS.KANBAN_SELECTED_PIPELINE, pipelineId.toString());
      } catch (error) {
        console.warn('[Kanban] Erro ao salvar pipeline no localStorage:', error);
      }
    },
    getSavedPipelineId() {
      try {
        return localStorage.getItem(LOCAL_STORAGE_KEYS.KANBAN_SELECTED_PIPELINE);
      } catch (error) {
        console.warn('[Kanban] Erro ao recuperar pipeline do localStorage:', error);
        return null;
      }
    },
    clearSavedPipeline() {
      try {
        localStorage.removeItem(LOCAL_STORAGE_KEYS.KANBAN_SELECTED_PIPELINE);
      } catch (error) {
        console.warn('[Kanban] Erro ao limpar pipeline do localStorage:', error);
      }
    },
    selectPipeline(pipeline) {
      this.selectedAttribute = pipeline;
      this.saveSelectedPipeline(pipeline.id);
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
      
      // Resetar colorMap para recarregar cores do backend
      this.colorMap = {};
      
      // Recarregar dados após edição para refletir mudanças na ordem dos estágios
      await this.fetchAttributes();
      if (this.selectedAttribute) {
        // Atualizar selectedAttribute com os dados mais recentes
        const updatedAttribute = this.listTypeAttributes.find(
          attr => attr.id === this.selectedAttribute.id
        );
        if (updatedAttribute) {
          // Atualizar selectedAttribute com dados frescos do backend
          // Usar Vue.set para garantir reatividade
          this.$set(this, 'selectedAttribute', { ...updatedAttribute });
          
          // Aguardar próximo tick para garantir que selectedAttribute foi atualizado
          await this.$nextTick();
          
          // Forçar recarregamento das cores antes de recriar colunas
          if (this.selectedAttribute.attribute_values && Array.isArray(this.selectedAttribute.attribute_values)) {
            this.selectedAttribute.attribute_values.forEach((value) => {
              if (typeof value === 'object' && value !== null && value.color) {
                const stageName = value.name || value.value || String(value);
                this.$set(this.colorMap, stageName, value.color);
              }
            });
          }
          
          await this.fetchContacts();
          
          // Aguardar próximo tick antes de recriar colunas
          await this.$nextTick();
          this.setupColumns();
        }
      }
    },
    async confirmDeletePipeline() {
      try {
        // Verificar quantos contatos estão usando este pipeline (apenas para informação)
        const contactsUsingPipeline = this.contacts.filter(contact => {
          const position = contact.pipeline_positions?.find(
            p => p.pipeline_id === this.selectedAttribute.id
          );
          return position && position.stage_id;
        });

        await this.$store.dispatch(
          'attributes/delete',
          this.selectedAttribute.id
        );
        
        // Limpar pipeline salvo se estiver deletando o pipeline atual
        const deletedPipelineId = this.selectedAttribute.id;
        this.selectedAttribute = null;
        const savedPipelineId = this.getSavedPipelineId();
        if (savedPipelineId && parseInt(savedPipelineId, 10) === deletedPipelineId) {
          this.clearSavedPipeline();
        }
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
        const contact = contacts[contactIndex];
        
        // Atualizar pipeline_positions em vez de custom_attributes
        if (!contact.pipeline_positions) {
          contact.pipeline_positions = [];
        }
        
        const positionIndex = contact.pipeline_positions.findIndex(
          p => p.pipeline_id === pipelineId
        );
        
        // Preservar dados existentes do pipeline_positions, incluindo assignee
        const currentPosition = contact.pipeline_positions[positionIndex];
        const updatedPosition = {
          pipeline_id: pipelineId,
          stage_id: newColumnValue,
          position: currentPosition?.position || 0,
          entered_at: currentPosition?.entered_at || new Date().toISOString(),
          deal_value: currentPosition?.deal_value || null,
          metadata: currentPosition?.metadata || {},
          assignee: currentPosition?.assignee || null, // ✅ PRESERVAR ASSIGNEE
        };
        
        if (positionIndex >= 0) {
          contact.pipeline_positions[positionIndex] = updatedPosition;
        } else {
          contact.pipeline_positions.push(updatedPosition);
        }

        contacts[contactIndex] = contact;

        this.pipelineCache[pipelineId] = {
          ...cachedData,
          contacts,
          lastUpdated: Date.now(),
        };

        // Forçar atualização do store para refletir a mudança imediatamente
        this.$store.commit('contacts/SET_CONTACTS', contacts);
      }
    },
    async handleDealValueUpdate({ contactId, additionalAttributes, value }) {
      // Verificar permissão de edição
      if (this.isViewerMode) {
        this.$store.dispatch('notifications/show', {
          message: this.$t('KANBAN.ERRORS.CANNOT_EDIT_CARD'),
          type: 'error',
        });
        return;
      }

      // Verificar se é editor (não admin) e se pode editar este card específico
      if (!this.isAdmin) {
        const contact = this.contacts.find(c => c.id === contactId);
        if (contact) {
          const currentPosition = contact.pipeline_positions?.find(
            p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
          );
          const cardAssigneeId = currentPosition?.assignee?.id || null;
          const currentUserId = this.currentUser?.id;

          // Editor só pode editar cards próprios ou sem dono
          if (cardAssigneeId && cardAssigneeId !== currentUserId) {
            this.$store.dispatch('notifications/show', {
              message: this.$t('KANBAN.ERRORS.CANNOT_EDIT_CARD'),
              type: 'error',
            });
            return;
          }
        }
      }

      // Encontrar o contato atual
      const contact = this.contacts.find(c => c.id === contactId);
      if (!contact || !this.selectedAttribute) {
        console.warn('[Kanban] Contact or selectedAttribute not found for deal value update:', contactId);
        return;
      }

      try {
        // Obter dados atuais do pipeline_positions
        const currentPosition = contact.pipeline_positions?.find(
          p => p.pipeline_id === this.selectedAttribute.id
        );
        
        if (!currentPosition) {
          console.warn('[Kanban] Pipeline position not found for contact:', contactId);
          return;
        }

        const stageId = currentPosition.stage_id;
        const position = currentPosition.position || 0;
        const enteredAt = currentPosition.entered_at || new Date().toISOString();
        const metadata = currentPosition.metadata || {};

        // Atualizar deal_value via pipeline_positions
        const response = await ContactAPI.updatePipelinePosition(
          contactId,
          this.selectedAttribute.id,
          stageId,
          position,
          enteredAt,
          value,
          metadata
        );

        // Atualizar pipeline_positions localmente
        if (contact.pipeline_positions) {
          const positionIndex = contact.pipeline_positions.findIndex(
            p => p.pipeline_id === this.selectedAttribute.id
          );
          
          const updatedPosition = {
            pipeline_id: response.data.pipeline_id,
            stage_id: response.data.stage_id,
            position: response.data.position,
            entered_at: response.data.entered_at,
            deal_value: response.data.deal_value,
            metadata: response.data.metadata || {},
            assignee: response.data.assignee || null,
          };
          
          if (positionIndex >= 0) {
            this.$set(contact.pipeline_positions, positionIndex, updatedPosition);
          } else {
            contact.pipeline_positions.push(updatedPosition);
          }
        }
        
        // Se o modal estiver aberto para este contato, atualizar o selectedCardContact também
        if (this.showCardModal && this.selectedCardContact.id === contactId) {
          if (!this.selectedCardContact.pipeline_positions) {
            this.$set(this.selectedCardContact, 'pipeline_positions', []);
          }
          const modalPositionIndex = this.selectedCardContact.pipeline_positions.findIndex(
            p => p.pipeline_id === this.selectedAttribute.id
          );
          if (modalPositionIndex >= 0) {
            this.$set(this.selectedCardContact.pipeline_positions, modalPositionIndex, {
              pipeline_id: response.data.pipeline_id,
              stage_id: response.data.stage_id,
              position: response.data.position,
              entered_at: response.data.entered_at,
              deal_value: response.data.deal_value,
              metadata: response.data.metadata || {},
              assignee: response.data.assignee || null, // ✅ INCLUIR ASSIGNEE
            });
          }
        }
        
        // Reconstruir colunas para refletir a mudança (caso afete a ordenação)
        this.$nextTick(() => {
          this.setupColumns();
        });

        // Emitir evento de sucesso se necessário
        this.safeShowNotification(
          'success',
          this.$t('KANBAN.CARD.DEAL_VALUE_UPDATED')
        );
      } catch (error) {
        console.error('[Kanban] Error updating deal value:', error);
        
        // Reverter também o selectedCardContact se o modal estiver aberto
        if (this.showCardModal && this.selectedCardContact.id === contactId) {
          this.selectedCardContact = contact;
        }

        this.safeShowNotification(
          'error',
          error?.message || this.$t('CONTACTS.ERROR_UPDATE_CONTACT')
        );
      }
    },
    async handleWinLostUpdate({ contactId, winLostData, dealValue }) {
      if (!this.selectedAttribute) return;

      try {
        // Register operation for loading state
        const operationId = this.operationManager?.registerOperation(contactId, 'win_lost_update');

        // Obter dados atuais do pipeline_positions
        const contact = this.contacts.find(c => c.id === contactId);
        if (!contact) return;

        const currentPosition = contact.pipeline_positions?.find(
          p => p.pipeline_id === this.selectedAttribute.id
        );
        
        const stageId = currentPosition?.stage_id || getStage(contact, this.selectedAttribute.id);
        const position = currentPosition?.position || 0;
        const enteredAt = currentPosition?.entered_at || new Date().toISOString();
        
        // Atualizar metadata com win_lost
        const metadata = { ...(currentPosition?.metadata || {}) };
        metadata.win_lost = winLostData;

        // Atualizar via pipeline_positions
        const response = await ContactAPI.updatePipelinePosition(
          contactId,
          this.selectedAttribute.id,
          stageId,
          position,
          enteredAt,
          dealValue || currentPosition?.deal_value,
          metadata
        );

        // Atualizar pipeline_positions localmente
        if (contact.pipeline_positions) {
          const positionIndex = contact.pipeline_positions.findIndex(
            p => p.pipeline_id === this.selectedAttribute.id
          );
          
          const updatedPosition = {
            pipeline_id: response.data.pipeline_id,
            stage_id: response.data.stage_id,
            position: response.data.position,
            entered_at: response.data.entered_at,
            deal_value: response.data.deal_value,
            metadata: response.data.metadata || {},
            assignee: response.data.assignee || null,
          };
          
          if (positionIndex >= 0) {
            this.$set(contact.pipeline_positions, positionIndex, updatedPosition);
          } else {
            contact.pipeline_positions.push(updatedPosition);
          }
        }

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
      this.kanbanFilters.winLost = filter;
      // Forçar re-filtragem imediata
      this.$nextTick(() => {
        this.handleSearch(this.searchQuery || '');
      });
    },
    handleFiltersChanged(filters) {
      this.kanbanFilters = { ...filters };
      this.winLostFilter = filters.winLost || 'all';
      // Forçar re-filtragem imediata
      this.$nextTick(() => {
        this.handleSearch(this.searchQuery || '');
      });
    },
    getContactStage(contact) {
      // Verificar primeiro nas colunas filtradas, depois nas colunas originais
      const column = this.displayColumns.find(col =>
        col.items.some(item => item.id === contact.id)
      ) || this.columns.find(col =>
        col.items.some(item => item.id === contact.id)
      );
      
      // Se não encontrou na coluna, buscar pelo pipeline_positions
      if (!column && this.selectedAttribute) {
        const stageValue = getStage(contact, this.selectedAttribute.id);
        return stageValue || '';
      }
      
      return column ? column.title : '';
    },
    formatContactValue(contact) {
      if (!this.selectedAttribute) return '';
      const dealValue = getDealValue(contact, this.selectedAttribute.id) || 0;
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
      }).format(dealValue);
    },
    // Carregar uma página de contatos (modo lista)
    async loadContactsPage(page = 1) {
      if (!this.selectedAttribute) return;
      
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
      
      try {
        await this.$store.dispatch('contacts/filter', {
          page,
          queryPayload,
          resetState: page === 1,
        });
      } catch (error) {
        console.error('[Kanban] Error loading contacts page:', error);
      }
    },
    // Carregar página específica no modo lista
    async loadListPage(page) {
      if (page < 1 || page > this.totalListPages) return;
      this.listCurrentPage = page;
      await this.loadContactsPage(page);
    },
    getContactTimeInStage(contact) {
      if (!this.selectedAttribute) return '-';
      const enteredAt = getEnteredAt(contact, this.selectedAttribute.id);
      
      if (!enteredAt) return '-';
      
      const enteredAtTime = new Date(enteredAt).getTime();
      const now = Date.now();
      const timeDiff = now - enteredAtTime;
      const days = Math.floor(timeDiff / 86400000);
      
      return `${days}d`;
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
        // Chamar o método existente de atualização usando pipeline_positions
        await this.handleWinLostUpdate({
          contactId: data.contactId,
          winLostData: data.winLostData,
          dealValue: data.dealValue
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
    handleOpenCardModal(contact) {
      this.selectedCardContact = contact;
      this.showCardModal = true;
    },
    handleCloseCardModal() {
      this.showCardModal = false;
      this.selectedCardContact = {};
    },
    handleShowAssignOwnerConfirmation({ contact, onConfirm, onCancel }) {
      this.assignOwnerModalContact = contact;
      this.assignOwnerModalCallbacks = { onConfirm, onCancel };
      this.assignOwnerModalMessage = `Você quer se tornar responsável pelo card ${contact.name}?`;
      this.showAssignOwnerModal = true;
    },
    closeAssignOwnerModal() {
      if (this.assignOwnerModalCallbacks?.onCancel) {
        this.assignOwnerModalCallbacks.onCancel();
      }
      this.showAssignOwnerModal = false;
      this.assignOwnerModalContact = null;
      this.assignOwnerModalCallbacks = null;
      this.assignOwnerModalMessage = '';
    },
    async confirmAssignOwner() {
      this.showAssignOwnerModal = false;
      
      // Atribuir dono
      if (this.assignOwnerModalContact) {
        await this.handleAssignSelfAsOwner({ contactId: this.assignOwnerModalContact.id });
      }
      
      // Resolver promise após atribuir
      if (this.assignOwnerModalCallbacks?.onConfirm) {
        this.assignOwnerModalCallbacks.onConfirm();
      }
      
      this.assignOwnerModalContact = null;
      this.assignOwnerModalCallbacks = null;
      this.assignOwnerModalMessage = '';
    },
    async handleAssignSelfAsOwner({ contactId }) {
      try {
        const contact = this.contacts.find(c => c.id === contactId);
        if (!contact) return;
        
        const position = contact.pipeline_positions?.find(
          p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
        );
        
        if (!position) return;
        
        // Verificar se já tem dono (evitar chamadas duplicadas)
        const currentUser = this.$store.getters.getCurrentUser;
        if (position.assignee?.id === currentUser.id) {
          // Já é o dono, não precisa fazer nada
          return;
        }
        
        await ContactAPI.updatePipelinePosition(
          contactId,
          this.selectedAttribute.id,
          position.stage_id,
          position.position || 0,
          position.entered_at,
          position.deal_value,
          position.metadata,
          { updateAssignee: true, assigneeId: currentUser.id }
        );
        
        // Atualizar contato localmente
        if (position) {
          position.assignee = {
            id: currentUser.id,
            name: currentUser.name,
            available_name: currentUser.available_name,
            avatar_url: currentUser.avatar_url,
            thumbnail: currentUser.avatar_url
          };
        }
        
        useAlert('Você é o responsável');
      } catch (error) {
        console.error('[KanbanAttributes] Error assigning self as owner:', error);
        useAlert('Erro ao atribuir');
      }
    },
    // Carregar uma página de contatos (modo lista)
    async loadContactsPage(page = 1) {
      if (!this.selectedAttribute) return;
      
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
      
      try {
        await this.$store.dispatch('contacts/filter', {
          page,
          queryPayload,
          resetState: page === 1,
        });
      } catch (error) {
        console.error('[Kanban] Error loading contacts page:', error);
      }
    },
    // Carregar página específica no modo lista
    async loadListPage(page) {
      if (page < 1 || page > this.totalListPages) return;
      this.listCurrentPage = page;
      await this.loadContactsPage(page);
    },
    getContactCurrentStage(contact) {
      if (!contact || !this.selectedAttribute) return '';
      return getStage(contact, this.selectedAttribute.id) || '';
    },
    async handleAssigneeUpdated({ contactId, assignee }) {
      // Atualizar contato localmente
      const contact = this.contacts.find(c => c.id === contactId);
      if (contact) {
        const position = contact.pipeline_positions?.find(
          p => p.pipeline_id === this.selectedAttribute.id || p.pipeline_id === parseInt(this.selectedAttribute.id, 10)
        );
        if (position) {
          // Atualizar assignee: null quando removido, objeto quando atribuído
          position.assignee = assignee;
        }
      }
      
      // Reconstruir colunas para aplicar filtro de visibilidade (card pode sumir/aparecer)
      this.setupColumns();
    },
    async handleStageChangeFromModal({ contactId, newStage, oldStage }) {
      const contact = this.contacts.find(c => c.id === contactId);
      if (!contact || !this.selectedAttribute) return;

      // Obter dados atuais do pipeline_positions
      const currentPosition = contact.pipeline_positions?.find(
        p => p.pipeline_id === this.selectedAttribute.id
      );
      
      const dealValue = currentPosition?.deal_value;
      const metadata = currentPosition?.metadata || {};
      const position = currentPosition?.position || 0;
      const enteredAt = new Date().toISOString();

      try {
        // Atualizar via pipeline_positions
        const response = await ContactAPI.updatePipelinePosition(
          contactId,
          this.selectedAttribute.id,
          newStage,
          position,
          enteredAt,
          dealValue,
          metadata
        );

        // Atualizar pipeline_positions localmente
        if (contact.pipeline_positions) {
          const positionIndex = contact.pipeline_positions.findIndex(
            p => p.pipeline_id === this.selectedAttribute.id
          );
          
          const updatedPosition = {
            pipeline_id: response.data.pipeline_id,
            stage_id: response.data.stage_id,
            position: response.data.position,
            entered_at: response.data.entered_at,
            deal_value: response.data.deal_value,
            metadata: response.data.metadata || {},
          };
          
          if (positionIndex >= 0) {
            this.$set(contact.pipeline_positions, positionIndex, updatedPosition);
          } else {
            contact.pipeline_positions.push(updatedPosition);
          }
        }

        // Reconstruir colunas
        this.setupColumns();
      } catch (error) {
        console.error('[Kanban] Error updating stage from modal:', error);
      }

      // Criar operationId para tracking
      const operationId = this.operationManager?.registerOperation(contactId, newStage) || `stage-change-${Date.now()}`;

      // Usar o método existente updateCardPosition
      await this.updateCardPosition(contact, newStage, operationId);
    },
    async handleUndoWinLost({ contactId }) {
      if (!this.selectedAttribute) return;

      try {
        // Register operation for loading state
        const operationId = this.operationManager?.registerOperation(contactId, 'undo_win_lost');

        // Obter dados atuais do pipeline_positions
        const contact = this.contacts.find(c => c.id === contactId);
        if (!contact) return;

        const currentPosition = contact.pipeline_positions?.find(
          p => p.pipeline_id === this.selectedAttribute.id
        );
        
        const stageId = currentPosition?.stage_id || getStage(contact, this.selectedAttribute.id);
        const position = currentPosition?.position || 0;
        const enteredAt = currentPosition?.entered_at || new Date().toISOString();
        const dealValue = currentPosition?.deal_value;
        
        // Remover win_lost do metadata
        const metadata = { ...(currentPosition?.metadata || {}) };
        delete metadata.win_lost;

        // Atualizar via pipeline_positions
        const response = await ContactAPI.updatePipelinePosition(
          contactId,
          this.selectedAttribute.id,
          stageId,
          position,
          enteredAt,
          dealValue,
          metadata
        );

        // Atualizar pipeline_positions localmente
        if (contact.pipeline_positions) {
          const positionIndex = contact.pipeline_positions.findIndex(
            p => p.pipeline_id === this.selectedAttribute.id
          );
          
          const updatedPosition = {
            pipeline_id: response.data.pipeline_id,
            stage_id: response.data.stage_id,
            position: response.data.position,
            entered_at: response.data.entered_at,
            deal_value: response.data.deal_value,
            metadata: response.data.metadata || {},
            assignee: response.data.assignee || null,
          };
          
          if (positionIndex >= 0) {
            this.$set(contact.pipeline_positions, positionIndex, updatedPosition);
          } else {
            contact.pipeline_positions.push(updatedPosition);
          }
        }

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

  // Permitir scroll quando estiver em dashboard ou lista
  .list-view-container,
  .dashboard-container {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
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
  transition: opacity 0.2s ease-in-out;
  animation: fadeIn 0.3s ease-in-out;
  @apply bg-slate-50 dark:bg-slate-900;
}

.kanban-columns-container {
  flex: 1;
  overflow-x: auto;
  overflow-y: hidden;
  height: 100%;
  padding: var(--space-small);
  @apply bg-slate-50 dark:bg-slate-900;
}

.kanban-columns {
  display: inline-flex;
  gap: var(--space-normal);
  padding: var(--space-small);
  height: 100%;
  align-items: stretch;
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

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
</style>

