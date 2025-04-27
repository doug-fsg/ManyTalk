<template>
  <div class="kanban-container" :class="{ 'dark-mode': isDarkMode }">
    <div class="kanban-header">
      <div class="kanban-header--left">
        <h1 class="kanban-title">
          {{ $t('KANBAN.TITLE') || 'Kanban' }}
        </h1>
        <span class="kanban-subtitle">
          {{ 
            $t('KANBAN.SUBTITLE') ||
            'Visualização baseada em atributos personalizados' 
          }}
        </span>
      </div>
      <div class="kanban-header--right">
        <woot-button
          v-tooltip="$t('KANBAN.REFRESH')"
          variant="clear"
          color-scheme="secondary"
          class="refresh-button"
          icon="refresh"
          @click="fetchAttributes"
        />
        <woot-button
          v-if="isAdmin"
          v-tooltip="debugMode ? 'Desativar Depuração' : 'Ativar Depuração'"
          variant="clear"
          :color-scheme="debugMode ? 'alert' : 'secondary'"
          class="debug-button"
          icon="bug"
          @click="toggleDebugMode"
        />
        <div class="search-box">
          <woot-input
            v-model="searchQuery"
            :placeholder="
              $t('KANBAN.SEARCH_PLACEHOLDER') ||
              'Buscar contatos por nome ou número'
            "
            small
            icon="search"
            @input="handleSearch"
          />
        </div>
        <woot-button
          v-tooltip="
            $t('KANBAN.CREATE_NEW_ATTRIBUTE') || 'Criar novo atributo Kanban'
          "
          variant="smooth"
          color-scheme="primary"
          size="small"
          icon="add"
          @click="openCreateAttributeModal"
        >
          {{ $t('KANBAN.CREATE_NEW') || 'Criar Kanban' }}
        </woot-button>
      </div>
    </div>

    <div 
      class="kanban-select-attribute"
      v-if="
        !selectedAttribute && attributes.length && listTypeAttributes.length
      "
    >
      <div class="select-attribute-content">
        <h2>
          {{ 
            $t('KANBAN.SELECT_ATTRIBUTE') || 
            'Selecione um atributo para visualizar no Kanban'
          }}
        </h2>
        <p>
          {{
            $t('KANBAN.SELECT_ATTRIBUTE_DESCRIPTION') ||
            'Escolha um atributo do tipo lista para organizar seus contatos'
          }}
        </p>
        
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
        <h2>
          {{ 
            $t('KANBAN.NO_KANBAN_ATTRIBUTES') ||
            'Nenhum atributo para Kanban disponível' 
          }}
        </h2>
        <p>
          {{ 
            $t('KANBAN.CREATE_KANBAN_ATTRIBUTE_DESCRIPTION') || 
            'Para usar o Kanban, crie um atributo personalizado do tipo lista (tipo 6) para contatos (modelo 1)'
          }}
        </p>
        <woot-button
          size="large"
          variant="primary"
          @click="goToAttributesSettings"
        >
          {{ $t('KANBAN.CREATE_ATTRIBUTE') || 'Criar atributo' }}
        </woot-button>
      </div>
    </div>

    <div v-if="selectedAttribute && !uiFlags.isFetching" class="kanban-board">
      <div class="kanban-attribute-header">
        <div class="attribute-header-content">
          <h3>
            {{
              $t('KANBAN.VIEWING_BY_ATTRIBUTE', {
                attribute: selectedAttribute.attribute_display_name,
              })
            }}
          </h3>
          <p class="sync-description">
            {{ $t('KANBAN.SYNC_DESCRIPTION') }}
          </p>
        </div>
        <woot-button
          variant="clear"
          size="small"
          @click="selectedAttribute = null"
        >
          {{ $t('KANBAN.CHANGE_ATTRIBUTE') || 'Mudar' }}
        </woot-button>
      </div>
      
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
          <div 
            v-for="column in displayColumns"
            :key="column.id"
            class="kanban-column"
            :data-id="column.id"
            :data-title="column.title"
          >
            <div 
              class="column-header"
              :style="{ borderTopColor: column.color }"
              :data-title="column.title"
            >
              <span class="column-title">{{ column.title }}</span>
              <span class="column-count">{{ column.items.length }}</span>
            </div>
            <div class="column-content">
              <draggable
                v-model="column.items"
                class="column-items"
                :data-column-id="column.id"
                :data-column-title="column.title"
                group="items"
                animation="150"
                ghost-class="ghost-card"
                @end="onItemMoved"
              >
                <div
                  v-for="contact in column.items"
                  :key="contact.id"
                  class="kanban-card"
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
                        @click.stop="openContact(contact.id)"
                        v-tooltip="
                          $t('KANBAN.VIEW_CONTACT') || 'Visualizar contato'
                        "
                      >
                        <i class="icon-eye" />
                      </span>
                      <span 
                        class="action-icon remove-icon" 
                        @click.stop="removeCardFromKanban(contact.id)"
                        v-tooltip="
                          $t('KANBAN.REMOVE_CARD') || 'Remover do Kanban'
                        "
                      >
                        <i class="icon-trash" />
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
                </div>
                <div v-if="!column.items.length" class="empty-column">
                  <p>{{ $t('KANBAN.NO_CONTACTS') || 'Nenhum contato' }}</p>
                </div>
              </draggable>
            </div>
          </div>
        </draggable>
      </div>
    </div>

    <woot-modal :show.sync="showFilterModal" :on-close="closeFilterModal">
      <div class="filter-modal">
        <woot-modal-header
          :header-title="$t('KANBAN.FILTER_CONTACTS') || 'Filtrar Contatos'"
          :header-content="
            $t('KANBAN.FILTER_DESCRIPTION') ||
            'Filtre os contatos exibidos no Kanban'
          "
        />
        <div class="filter-content">
          <!-- Implementar filtros de contato aqui -->
        </div>
        <div class="modal-footer">
          <woot-button variant="clear" @click="closeFilterModal">
            {{ $t('COMMON.CANCEL') || 'Cancelar' }}
          </woot-button>
          <woot-button variant="primary" @click="applyFilters">
            {{ $t('COMMON.APPLY') || 'Aplicar' }}
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
              {{ $t('ATTRIBUTES_MGMT.ADD.CANCEL_BUTTON_TEXT') || 'Cancelar' }}
            </woot-button>
            <woot-button variant="primary" @click="createKanbanAttribute">
              {{ $t('ATTRIBUTES_MGMT.ADD.SUBMIT') || 'Criar' }}
            </woot-button>
          </div>
        </div>
      </div>
    </woot-modal>

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

// Criar um barramento de eventos local se não existir um global
const eventBus = new Vue();

export default {
  components: {
    draggable,
    TagsInput,
  },
  data() {
    return {
      columns: [],
      selectedAttribute: null,
      showFilterModal: false,
      showCreateAttributeModal: false,
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
      // Sistema de detecção de ciclos por tempo
      cycleDetectionTimer: null,
      updateTimestamps: [],
      cycleDetectionActive: false,
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
      
      // Adicionar ouvinte para o evento de limpeza
      this.bus.$on('kanban_clear_updates', this.clearUpdateCache);
    }
    
    // Iniciar sistema de detecção de ciclos
    this.startCycleDetection();
    
    // Sobrescrever o watcher de contacts para evitar loops
    if (this.$options.watch && this.$options.watch.contacts) {
      const originalWatcher = this.$options.watch.contacts.handler;
      this.$watch('contacts', newVal => {
        // Evitar execução se estivermos processando uma atualização
        if (this.processingUpdate || this.syncLock || this.currentOperationId) {
          if (this.debugMode) {
            // eslint-disable-next-line no-console
            console.log('[KanbanWatch] Ignorando watcher de contatos durante operação');
          }
          return;
        }
        
        // Chamar o watcher original se não estiver bloqueado
        originalWatcher.call(this, newVal);
      });
    }
    
    if (this.debugMode) {
      // eslint-disable-next-line no-console
      console.log('[KanbanLog] Componente Kanban montado, event bus configurado');
    }
  },
  beforeDestroy() {
    // Usar o bus armazenado na propriedade
    if (this.bus) {
      this.bus.$off(BUS_EVENTS.THEME_CHANGE, this.checkDarkMode);
      this.bus.$off(
        'contact_attribute_updated',
        this.handleContactAttributeUpdate
      );
      this.bus.$off('contact_updated', this.handleContactUpdate);
      this.bus.$off(
        'contact_attribute_removed',
        this.handleContactAttributeRemoved
      );
      this.bus.$off(
        'contact_attribute_removed_from_kanban',
        this.handleAttributeRemovedFromKanban
      );
      this.bus.$off('kanban_clear_updates', this.clearUpdateCache);
    }
    
    // Limpar sistema de detecção de ciclos
    this.stopCycleDetection();
    
    if (this.debugMode) {
      // eslint-disable-next-line no-console
      console.log(
        '[KanbanLog] Componente Kanban destruído, event listeners removidos'
      );
    }
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
    handleContactAttributeUpdate(contact, attribute, payload) {
      // Identificação rápida de evento
      const attributeKey = Object.keys(attribute)[0];
      const attributeValue = attribute[attributeKey];
      
      // Gerar um ID de operação único para rastreamento
      const operationId = `attr-${contact.id}-${attributeKey}-${attributeValue}-${Date.now()}`;
      
      // Registrar timestamp para detecção de ciclos
      if (!this.cycleDetectionActive) {
        const now = Date.now();
        this.updateTimestamps.push(now);
      }
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] Evento recebido para atualização de atributo:', { 
          contactId: contact.id, 
          attributeKey, 
          attributeValue,
          fromKanban: payload && payload._fromKanban,
          operationId,
        });
      }
      
      // PROTEÇÃO CONTRA RECURSÃO: Detectar número excessivo de tentativas
      this.updateAttempts += 1;
      if (this.updateAttempts > 10) {
        // Limite de segurança atingido, limpar e sair para quebrar o ciclo
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.error('[KanbanVerificação] ⚠️ CICLO DETECTADO - Limite de tentativas de atualização excedido. Reiniciando contador.');
        }
        this.updateAttempts = 0;
        this.resetAllLocks();
        return;
      }
      
      // Verificar se este é o atributo do Kanban
      if (!this.selectedAttribute || 
          this.selectedAttribute.attribute_key !== attributeKey) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ IGNORANDO - Atributo diferente do Kanban atual');
        }
        return;
      }
      
      // Registrar esta operação para evitar processamento circular
      if (this.operationRegistry[`${contact.id}-${attributeValue}`]) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ IGNORANDO - Operação já registrada no rastreador global');
        }
        return;
      }
      
      // Se a atualização veio do próprio Kanban, ignorar completamente
      if (payload && (payload._fromKanban || payload._kanbanOperation)) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ IGNORANDO - Atualização iniciada pelo próprio Kanban');
        }
        // Reduzir contador para evitar falsas detecções de ciclo
        this.updateAttempts = Math.max(0, this.updateAttempts - 1);
        return;
      }
      
      // Verificar se estamos em meio a um processamento
      if (this.processingUpdate || this.syncLock) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ IGNORANDO - Processamento já em andamento');
        }
        return;
      }
      
      // Verificar no mapa de atualizações recentes
      const updateKey = `${contact.id}-${attributeValue}`;
      const now = Date.now();
      
      if (this.recentUpdates.has(updateKey)) {
        const lastUpdate = this.recentUpdates.get(updateKey);
        if (now - lastUpdate < 8000) {
          if (this.debugMode) {
            // eslint-disable-next-line no-console
            console.log('[KanbanVerificação] ✅ IGNORANDO - Atualização recente detectada no cache');
          }
        return;
        }
      }
      
      // Verificar se o card já está na coluna correta
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] Verificando posição do card nas colunas...');
      }
      
      // Encontrar em qual coluna o contato já está (se estiver)
      let cardAlreadyInCorrectColumn = false;
      let currentColumnTitle = null;
      
      // Procurar o contato nas colunas
      for (let colIndex = 0; colIndex < this.columns.length; colIndex += 1) {
        const column = this.columns[colIndex];
        const contactInColumn = column.items.find(
          item => item.id === contact.id
        );
        if (contactInColumn) {
          currentColumnTitle = column.title;
          // Se o card já está na coluna correspondente ao novo valor do atributo, não precisa atualizar
          if (column.title === attributeValue) {
            cardAlreadyInCorrectColumn = true;
          }
          break;
        }
      }
      
      if (cardAlreadyInCorrectColumn) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ IGNORANDO - Card já está na coluna correta', {
            coluna: currentColumnTitle,
            valorAtributo: attributeValue,
          });
        }
        return;
      }
      
      // Ativar os controles de proteção
      this.activateSyncLock();
      this.processingUpdate = true;
      this.currentOperationId = operationId;
      
      // Registrar esta atualização imediatamente para evitar duplicações
      this.recentUpdates.set(updateKey, now);
      
      // Registrar no rastreador global por 20 segundos
      this.operationRegistry[updateKey] = true;
        setTimeout(() => {
        delete this.operationRegistry[updateKey];
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Operação removida do registro:', updateKey);
        }
      }, 20000);
      
      // Se chegou aqui, é uma atualização externa válida e o card precisa ser movido
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] ⚠️ ATUALIZANDO - Card precisa ser movido para a nova coluna', {
          colunaAtual: currentColumnTitle || 'não encontrado',
          novaColuna: attributeValue,
          operationId,
        });
      }
      
      // Atualizar visualmente sem disparar novas chamadas à API
      this.setupColumnsWithLock();
      
      // Liberar controles após um tempo seguro
      setTimeout(() => {
        this.processingUpdate = false;
        this.releaseSyncLock();
        this.currentOperationId = null;
        
        // Reduzir contador pois esta operação foi concluída sem problemas
        this.updateAttempts = Math.max(0, this.updateAttempts - 1);
        
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Controles liberados após atualização');
        }
      }, 3000);
    },
    handleContactAttributeRemoved(contact, attributeKey) {
      console.log('[KanbanLog] Recebeu evento contact_attribute_removed', { 
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
        console.log('[KanbanLog] Atualizando colunas devido à remoção externa');
        
        // Atualizar colunas para remover o card
        this.setupColumns();
        
        // Mostrar notificação
        this.$store.dispatch('notifications/show', {
          type: 'info',
          message: this.$t('KANBAN.CONTACT_ATTRIBUTE_REMOVED') || 'O contato foi removido do Kanban porque o atributo foi apagado',
        });
      }
    },
    handleAttributeRemovedFromKanban(contactId, attributeKey) {
      this.debug('Recebeu evento contact_attribute_removed_from_kanban', { contactId, attributeKey });
      // Este evento é acionado quando um atributo é removido a partir do Kanban
      // Já com a flag fromKanban, então apenas atualizamos as colunas sem emitir outros eventos
      if (this.selectedAttribute && this.selectedAttribute.attribute_key === attributeKey) {
        this.debug('Atualizando colunas devido à remoção pelo Kanban');
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
        // Buscar todos os contatos para o kanban - usar page: 1 sem "append" para limpar contatos anteriores
        await this.$store.dispatch('contacts/get', { 
          page: 1, 
          per_page: 50
        });
        
        // Se houver mais páginas, continue buscando, mas com append:true
        const totalPages = Math.ceil(this.contactMeta.count / 50);
        
        if (totalPages > 1) {
          for (let page = 2; page <= totalPages && page <= 5; page++) {
            await this.$store.dispatch('contacts/get', { 
              page, 
              per_page: 50, 
              append: true 
            });
          }
        }
        
        // Agora que temos os contatos, configure as colunas
        this.setupColumns();
      } catch (error) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('CONTACTS.LIST.FETCH_ERROR'),
        });
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
      if (now - this.lastColumnUpdateTime < 1000) { // Limitar a 1 atualização por segundo
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Limitando taxa de atualizações de coluna');
        }
        setTimeout(() => this.setupColumns(), 1000);
        return;
      }
      this.lastColumnUpdateTime = now;

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
    onItemMoved(event) {
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanLog] Evento de movimento recebido:', event);
      }
      
      // Prevenir processamento duplicado ou durante trava
      if (this.processingUpdate || this.syncLock || this.currentOperationId) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Ignorando evento, já estamos processando uma atualização ou trava ativa');
        }
        return;
      }

      // Verificar se o kanban está em condições de processar movimento
      if (this.updateAttempts > 5) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.error('[KanbanLog] Muitas atualizações recentes, aguardando estabilização...');
        }
        // Aguardar estabilização
        setTimeout(() => {
          this.updateAttempts = 0;
          this.resetAllLocks();
        }, 3000);
        return;
      }
      
      // Ativar trava de sincronização
      this.activateSyncLock();
      this.processingUpdate = true;
      
      try {
        // 1. Identificar as colunas de origem e destino
        const sourceColumnTitle = event.from.dataset.columnTitle;
        const targetColumnTitle = event.to.dataset.columnTitle;
        
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Movendo de:', sourceColumnTitle, 'para:', targetColumnTitle);
        }
        
        if (!sourceColumnTitle || !targetColumnTitle) {
          // eslint-disable-next-line no-console
          console.error('[KanbanLog] Colunas não identificadas corretamente');
          this.processingUpdate = false;
          this.releaseSyncLock();
        return;
      }
      
        // 2. Extrair o ID do elemento diretamente (elemento arrastado)
        const cardElement = event.item;
        const contactId = parseInt(cardElement.dataset.contactId, 10);
        
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Elemento do card:', cardElement);
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Dataset do card:', cardElement.dataset);
        }
        
        if (isNaN(contactId)) {
          // eslint-disable-next-line no-console
          console.error('[KanbanLog] Não foi possível obter o ID do contato do dataset');
          
          // Tentar extrair do elemento oculto
          const hiddenIdElement = cardElement.querySelector('.hidden-contact-id');
          if (hiddenIdElement) {
            const hiddenId = parseInt(hiddenIdElement.textContent.trim(), 10);
            if (!isNaN(hiddenId)) {
              if (this.debugMode) {
                // eslint-disable-next-line no-console
                console.log('[KanbanLog] ID obtido do elemento oculto:', hiddenId);
              }
              
              // Encontrar o contato nos nossos dados
              const contact = this.contacts.find(c => c.id === hiddenId);
              
              if (contact) {
                this.updateContactColumn(contact, sourceColumnTitle, targetColumnTitle);
                return;
              }
            }
          }
          
          // Como alternativa, tentar obter do modelo após o movimento completado
          // Neste ponto, o item já foi movido para a coluna de destino, então procuramos lá
          const targetColumn = this.columns.find(col => col.title === targetColumnTitle);
          
          if (!targetColumn || !targetColumn.items || !targetColumn.items.length) {
            // eslint-disable-next-line no-console
            console.error('[KanbanLog] Coluna de destino vazia ou sem itens');
            this.processingUpdate = false;
            this.releaseSyncLock();
            return;
          }
          
          // Pegamos o item que foi movido - deve ser o último inserido na posição do newIndex
          const movedContact = targetColumn.items[event.newIndex];
          
          if (!movedContact || !movedContact.id) {
            // eslint-disable-next-line no-console
            console.error('[KanbanLog] Não foi possível identificar o contato movido');
            this.processingUpdate = false;
            this.releaseSyncLock();
            return;
          }
          
          // Agora temos o contato!
          this.updateContactColumn(movedContact, sourceColumnTitle, targetColumnTitle);
        } else {
          // Encontrar o contato nos nossos dados 
          const contact = this.contacts.find(c => c.id === contactId);
          
          if (!contact) {
            // eslint-disable-next-line no-console
            console.error('[KanbanLog] Contato não encontrado nos dados, ID:', contactId);
            this.processingUpdate = false;
            this.releaseSyncLock();
            return;
          }
          
          this.updateContactColumn(contact, sourceColumnTitle, targetColumnTitle);
        }
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error('[KanbanLog] Erro ao processar movimentação:', error);
        this.processingUpdate = false;
        this.releaseSyncLock();
      }
    },
    // Método auxiliar para atualizar o atributo do contato
    updateContactColumn(contact, sourceColumnTitle, targetColumnTitle) {
      if (sourceColumnTitle === targetColumnTitle) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] Origem e destino são iguais, nenhuma ação necessária', {
            fonte: sourceColumnTitle,
            destino: targetColumnTitle,
          });
        }
        this.processingUpdate = false;
        this.releaseSyncLock();
        return;
      }
      
      // Registrar timestamp para detecção de ciclos
      if (!this.cycleDetectionActive) {
        const now = Date.now();
        this.updateTimestamps.push(now);
      }
      
      // Verificar se o contato já possui este valor no atributo
      const attributeKey = this.selectedAttribute.attribute_key;
      const currentAttributeValue = contact.custom_attributes?.[attributeKey];
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] Comparando valores do atributo:', {
          valorAtualDoAtributo: currentAttributeValue,
          valorDaColuna: targetColumnTitle,
          iguais: currentAttributeValue === targetColumnTitle,
        });
      }
      
      // Se o valor atual já for igual ao valor de destino, não fazer nada
      if (currentAttributeValue === targetColumnTitle) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ ATUALIZAÇÃO PAUSADA - Contato já está com o valor correto no atributo');
        }
        this.processingUpdate = false;
        this.releaseSyncLock();
        return;
      }
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] ⚠️ ATUALIZANDO - Os valores são diferentes, prosseguindo com atualização');
        // eslint-disable-next-line no-console
        console.log('[KanbanLog] Contato identificado:', { 
          id: contact.id,
          nome: contact.name,
        });
      }

      // Verificar se esta atualização já foi processada recentemente
      const updateKey = `${contact.id}-${targetColumnTitle}`;
      const now = Date.now();
      const operationId = `move-${contact.id}-${targetColumnTitle}-${now}`;
      
      // PROTEÇÃO CONTRA RECURSÃO: Detectar número excessivo de tentativas
      this.updateAttempts += 1;
      if (this.updateAttempts > 10) {
        // Limite de segurança atingido
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.error('[KanbanVerificação] ⚠️ CICLO DETECTADO - Limite de tentativas excedido. Reiniciando.');
        }
        this.updateAttempts = 0;
        this.resetAllLocks();
        return;
      }
      
      // Verificar no registro global de operações
      if (this.operationRegistry[updateKey]) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ ATUALIZAÇÃO PAUSADA - Operação já registrada no rastreador global');
        }
        this.processingUpdate = false;
        this.releaseSyncLock();
        return;
      }
      
      if (this.recentUpdates.has(updateKey)) {
        const lastUpdate = this.recentUpdates.get(updateKey);
        if (now - lastUpdate < 10000) { // 10 segundos de proteção
          if (this.debugMode) {
            // eslint-disable-next-line no-console
            console.log('[KanbanVerificação] ✅ ATUALIZAÇÃO PAUSADA - Duplicação detectada no controle de cache');
          }
          this.processingUpdate = false;
          this.releaseSyncLock();
          return;
        }
      }
      
      // Registrar esta atualização imediatamente
      this.recentUpdates.set(updateKey, now);
      this.operationRegistry[updateKey] = true;
      this.currentOperationId = operationId;
      
      // Adicionar um tempo para limpar este registro
      setTimeout(() => {
        delete this.operationRegistry[updateKey];
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Operação removida do registro:', updateKey);
        }
      }, 20000);
      
      // Preparar e enviar a atualização
      const updatedAttributes = {
        ...contact.custom_attributes,
        [attributeKey]: targetColumnTitle,
      };
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanLog] Atualizando atributos:', updatedAttributes);
      }
      
      // Atualizar o contato no backend com flags especiais para evitar reprocessamento
      this.$store.dispatch('contacts/updateContact', {
        id: contact.id,
        custom_attributes: updatedAttributes,
        _fromKanban: true,
        _kanbanOperation: operationId,
        _kanbanUpdateTimestamp: now,
      })
      .then(response => {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanLog] Contato atualizado com sucesso:', response);
        }
        
        // Atualizar o contato no modelo local também
        contact.custom_attributes = updatedAttributes;
        
        // Mostrar notificação de sucesso
        this.$store.dispatch('notifications/show', {
          type: 'success',
          message: 
            this.$t('KANBAN.CARD_MOVED_SUCCESS') || 'Card movido com sucesso',
        });
        
        // Reduzir contador pois esta operação foi concluída sem problemas
        this.updateAttempts = Math.max(0, this.updateAttempts - 1);
      })
      .catch(error => {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.error('[KanbanLog] Erro ao atualizar contato:', error);
        }
        
        // Mostrar notificação de erro
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: 
            this.$t('KANBAN.CARD_MOVED_ERROR') || 'Erro ao mover o card',
        });
      })
      .finally(() => {
        // Limpar a flag de processamento após 2 segundos
        setTimeout(() => {
          this.processingUpdate = false;
          
          if (this.debugMode) {
            // eslint-disable-next-line no-console
            console.log('[KanbanLog] Flag de processamento desativada');
          }
          
          // Liberar a trava de sincronização
          this.releaseSyncLock();
          this.currentOperationId = null;
          
          // Remover do mapa de atualizações recentes após 45 segundos
          setTimeout(() => {
            this.recentUpdates.delete(updateKey);
            
            if (this.debugMode) {
              // eslint-disable-next-line no-console
              console.log(
                '[KanbanLog] Chave removida do mapa de atualizações recentes:',
                updateKey
              );
            }
          }, 45000); // 45 segundos para garantir que não ocorra loop
        }, 2000); // 2 segundos para dar mais tempo
      });
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
    handleSearch() {
      // Se não houver texto de busca, mostrar todos os contatos
      if (!this.searchQuery.trim()) {
        this.resetFilteredColumns();
        return;
      }
      
      const searchTermLower = this.searchQuery.toLowerCase();
      
      // Filtrar contatos em todas as colunas
      this.filteredColumns = this.columns.map(column => {
        // Clone da coluna com filtro de itens
        const filteredItems = column.items.filter(contact => {
          // Buscar por nome
          if (contact.name && contact.name.toLowerCase().includes(searchTermLower)) {
            return true;
          }
          
          // Buscar por email
          if (contact.email && contact.email.toLowerCase().includes(searchTermLower)) {
            return true;
          }
          
          // Buscar por telefone
          if (contact.phone_number && contact.phone_number.toLowerCase().includes(searchTermLower)) {
            return true;
          }
          
          return false;
        });
        
        return {
          ...column,
          items: filteredItems
        };
      });
    },
    
    resetFilteredColumns() {
      this.filteredColumns = [...this.columns];
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
          message: this.$t('ATTRIBUTES_MGMT.ADD.FORM.VALIDATION_ERROR') || 'Por favor, preencha todos os campos',
        });
        return;
      }
      
      try {
        // Criar atributo personalizado do tipo lista
        const attributeData = {
          attribute_display_name: this.newAttributeData.display_name,
          attribute_display_type: 'list',
          attribute_description: this.newAttributeData.display_name,
          attribute_key: this.newAttributeData.display_name.toLowerCase().replace(/\s+/g, '_'),
          attribute_values: this.attributeValues,
          attribute_model: 'contact_attribute',
        };
        
        await this.$store.dispatch('attributes/create', attributeData);
        
        // Fechar o modal e recarregar atributos
        this.closeCreateAttributeModal();
        this.fetchAttributes();
        
        this.$store.dispatch('notifications/show', {
          type: 'success',
          message: this.$t('ATTRIBUTES_MGMT.API.CREATE_SUCCESS') || 'Atributo criado com sucesso',
        });
      } catch (error) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('ATTRIBUTES_MGMT.API.CREATE_ERROR') || 'Erro ao criar atributo',
        });
      }
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
      if (!this.selectedAttribute) {
        return;
      }
      
      const attrKey = this.selectedAttribute.attribute_key;
      this.debug('Iniciando remoção de card do Kanban', { contactId, attrKey });
      
      // Gerar ID de operação para rastreamento
      const operationId = `remove-${contactId}-${attrKey}-${Date.now()}`;
      
      // Registrar que essa operação foi iniciada pelo Kanban
      this.activateSyncLock();
      this.processingUpdate = true;
      this.currentOperationId = operationId;
      
      // Registrar no mapa de operações
      this.operationRegistry[`${contactId}-${attrKey}`] = true;
      
      this.$store.dispatch('contacts/deleteContactCustomAttribute', {
        id: contactId,
        attributeKey: attrKey,
        fromKanban: true,
        _kanbanOperation: operationId,
      }).then(() => {
        this.debug('Card removido com sucesso');
        this.$store.dispatch('notifications/show', {
          type: 'success',
          message: this.$t('KANBAN.CARD_REMOVED_SUCCESS') || 'Cartão removido do Kanban com sucesso',
        });
        
        // Atualizar as colunas localmente
        this.setupColumnsWithLock();
        
        // Limpar flags após um pequeno atraso
        setTimeout(() => {
          this.processingUpdate = false;
          this.releaseSyncLock();
          this.currentOperationId = null;
          this.debug('Flags de processamento liberados após remoção');
          
          // Reduzir contador pois concluímos com sucesso
          this.updateAttempts = Math.max(0, this.updateAttempts - 1);
          
          // Remover do registro após um tempo
          setTimeout(() => {
            delete this.operationRegistry[`${contactId}-${attrKey}`];
          }, 10000);
        }, 1000);
      }).catch(error => {
        this.processingUpdate = false;
        this.releaseSyncLock();
        this.currentOperationId = null;
        this.debug('Erro ao remover card, flags resetados', error);
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('CONTACTS.EDIT.API.DELETE_ERROR') || 'Erro ao remover cartão do Kanban',
        });
      });
    },
    toggleDebugMode() {
      this.debugMode = !this.debugMode;
    },
    // Método adicional para tratar eventos de atualização completa de contato
    handleContactUpdate(payload) {
      // Ignorar atualizações durante processamento
      if (this.processingUpdate || this.syncLock || this.currentOperationId) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] Ignorando atualização de contato durante operação');
        }
        return;
      }
      
      // Registrar timestamp para detecção de ciclos
      if (!this.cycleDetectionActive) {
        const now = Date.now();
        this.updateTimestamps.push(now);
      }
      
      // Verificar se é uma operação do próprio Kanban
      if (payload._fromKanban || payload._kanbanOperation) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] Ignorando atualização iniciada pelo Kanban');
        }
        return;
      }
      
      // Verificar no registro global de operações
      const updateKey = `${payload.id}-update`;
      if (this.operationRegistry[updateKey]) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] Ignorando atualização já registrada');
        }
        return;
      }
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] Evento de atualização de contato recebido', { 
          contactId: payload.id 
        });
      }
      
      // Se não há atributo selecionado, não há o que atualizar
      if (!this.selectedAttribute) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ IGNORANDO - Nenhum atributo selecionado no Kanban');
        }
        return;
      }
      
      // Extrair o atributo relevante
      const { attribute_key: attributeKey } = this.selectedAttribute;
      const attributeValue = this.getAttributeValue(payload.custom_attributes, attributeKey);
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] Valor do atributo para o contato atualizado:', {
          attributeKey,
          attributeValue
        });
      }
      
      // Registrar para evitar duplicações
      this.operationRegistry[updateKey] = true;
      setTimeout(() => {
        delete this.operationRegistry[updateKey];
      }, 10000);
      
      // PROTEÇÃO CONTRA RECURSÃO: Detectar número excessivo de tentativas
      this.updateAttempts += 1;
      if (this.updateAttempts > 10) {
        // Limite de segurança atingido
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.error('[KanbanVerificação] ⚠️ CICLO DETECTADO - Limite de tentativas excedido. Reiniciando.');
        }
        this.updateAttempts = 0;
        this.resetAllLocks();
        return;
      }
      
      // Verificar se o card já está na coluna correta
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] Verificando posição do card nas colunas...');
      }
      
      // Encontrar em qual coluna o contato já está (se estiver)
      let cardAlreadyInCorrectColumn = false;
      let currentColumnTitle = null;
      
      // Procurar o contato nas colunas
      for (let colIndex = 0; colIndex < this.columns.length; colIndex += 1) {
        const column = this.columns[colIndex];
        const contactInColumn = column.items.find(
          item => item.id === payload.id
        );
        if (contactInColumn) {
          currentColumnTitle = column.title;
          // Se o card já está na coluna correspondente ao novo valor do atributo, não precisa atualizar
          if (column.title === attributeValue) {
            cardAlreadyInCorrectColumn = true;
          }
          break;
        }
      }
      
      if (cardAlreadyInCorrectColumn) {
        if (this.debugMode) {
          // eslint-disable-next-line no-console
          console.log('[KanbanVerificação] ✅ IGNORANDO - Card já está na coluna correta', {
            coluna: currentColumnTitle,
            valorAtributo: attributeValue
          });
        }
        return;
      }
      
      // Se chegou aqui, é uma atualização externa válida e o card precisa ser movido
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanVerificação] ⚠️ ATUALIZANDO - Card precisa ser movido para a nova coluna', {
          colunaAtual: currentColumnTitle || 'não encontrado',
          novaColuna: attributeValue
        });
      }
      
      // Usar timeout para evitar conflitos de atualização
      setTimeout(() => {
        // Verificar novamente se ainda é seguro atualizar
        if (!this.processingUpdate && !this.syncLock && !this.currentOperationId) {
          this.activateSyncLock();
          
          // Atualizar visualmente sem disparar novas chamadas à API
          this.setupColumnsWithLock();
          
          // Liberar controles após um tempo seguro
          setTimeout(() => {
            this.releaseSyncLock();
            
            // Reduzir contador pois concluímos com sucesso
            this.updateAttempts = Math.max(0, this.updateAttempts - 1);
          }, 2000);
        }
      }, 500);
    },
    // Helper para lidar com valores de atributos potencialmente ausentes
    getAttributeValue(customAttributes, attributeKey) {
      if (!customAttributes) {
        return null;
      }
      return customAttributes[attributeKey] || null;
    },
    // Método para ativar a trava de sincronização
    activateSyncLock() {
      this.syncLock = true;
      
      // Cancelar qualquer timeout existente
      if (this.syncOperationTimeout) {
        clearTimeout(this.syncOperationTimeout);
      }
      
      // Definir um timeout de segurança para liberar a trava após 15 segundos
      // mesmo se algo der errado
      this.syncOperationTimeout = setTimeout(() => {
        if (this.syncLock) {
          this.syncLock = false;
          this.processingUpdate = false;
          if (this.debugMode) {
            // eslint-disable-next-line no-console
            console.log('[KanbanLog] Trava de sincronização liberada por timeout de segurança');
          }
        }
      }, 15000);
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanLog] Trava de sincronização ativada');
      }
    },
    // Método para liberar a trava de sincronização
    releaseSyncLock() {
      // Cancelar o timeout de segurança
      if (this.syncOperationTimeout) {
        clearTimeout(this.syncOperationTimeout);
        this.syncOperationTimeout = null;
      }
      
      // Liberar a trava
      this.syncLock = false;
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanLog] Trava de sincronização liberada');
      }
    },
    // Método para redefinir todas as travas
    resetAllLocks() {
      // Limpar todos os flags de controle
      this.processingUpdate = false;
      this.releaseSyncLock();
      this.currentOperationId = null;
      
      // Limpar operações em andamento
      this.operationRegistry = {};
      
      // Resetar sistema de detecção de ciclos
      this.updateTimestamps = [];
      this.cycleDetectionActive = false;
      
      // Restart do timer de detecção
      this.stopCycleDetection();
      this.startCycleDetection();
      
      if (this.debugMode) {
        // eslint-disable-next-line no-console
        console.log('[KanbanLog] Todas as travas foram redefinidas');
      }
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
      
      // Iniciar novo timer para monitorar atualizações
      this.cycleDetectionTimer = setInterval(() => {
        // Registrar timestamp da atualização
        const now = Date.now();
        this.updateTimestamps.push(now);
        
        // Manter apenas os últimos 10 segundos de atividade
        const tenSecondsAgo = now - 10000;
        this.updateTimestamps = this.updateTimestamps.filter(
          timestamp => timestamp > tenSecondsAgo
        );
        
        // Verificar frequência de atualizações
        if (this.updateTimestamps.length > 15) {
          // Mais de 15 atualizações em 10 segundos indica um ciclo
          if (!this.cycleDetectionActive) {
            this.cycleDetectionActive = true;
            
            // eslint-disable-next-line no-console
            console.error('[KanbanAutoreset] Ciclo de atualizações detectado! Resetando componente...');
            
            // Reset completo
            this.resetAllLocks();
            this.updateAttempts = 0;
            this.recentUpdates.clear();
            this.operationRegistry = {};
            this.updateTimestamps = [];
            
            // Notificar usuário
            this.$store.dispatch('notifications/show', {
              type: 'warning',
              message: 'Detectamos muitas atualizações no Kanban. O componente foi resetado para evitar problemas de desempenho.'
            });
            
            // Restore após um tempo
            setTimeout(() => {
              this.cycleDetectionActive = false;
            }, 5000);
          }
        }
      }, 1000);
    },
    stopCycleDetection() {
      if (this.cycleDetectionTimer) {
        clearInterval(this.cycleDetectionTimer);
        this.cycleDetectionTimer = null;
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
  padding: var(--space-normal);
  background-color: var(--s-50);
  color: var(--s-900);
  
  &.dark-mode {
    background-color: var(--b-800);
    color: var(--s-100);
    
    .kanban-column {
      background-color: var(--b-700);
      border: 1px solid var(--b-600);
    }
    
    .kanban-card {
      background-color: var(--b-600);
      border: 1px solid var(--b-500);
      
      &:hover {
        background-color: var(--b-500);
      }
    }
    
    .column-header {
      background-color: var(--b-700);
    }
    
    .card-subtitle {
      color: var(--s-300);
    }
    
    .empty-column p {
      color: var(--s-400);
    }
  }
}

.kanban-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--space-medium);
  
  .kanban-header--left {
    display: flex;
    flex-direction: column;
  }
  
  .kanban-header--right {
    display: flex;
    align-items: center;
    gap: var(--space-small);
  }
}

.kanban-title {
  font-size: var(--font-size-big);
  font-weight: var(--font-weight-bold);
  margin: 0;
}

.kanban-subtitle {
  font-size: var(--font-size-small);
  color: var(--s-700);
  
  .dark-mode & {
    color: var(--s-300);
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
}

.kanban-attribute-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--space-normal);
  
  .attribute-header-content {
    display: flex;
    flex-direction: column;
    
    h3 {
      margin: 0;
      font-size: var(--font-size-medium);
      font-weight: var(--font-weight-medium);
    }
    
    .sync-description {
      margin: var(--space-smaller) 0 0;
      font-size: var(--font-size-small);
      color: var(--s-600);
      
      .dark-mode & {
        color: var(--s-400);
      }
    }
  }
}

.kanban-columns-container {
  flex: 1;
  overflow-x: auto;
  overflow-y: hidden;
  padding-bottom: var(--space-smaller);
}

.kanban-columns {
  display: flex;
  gap: var(--space-normal);
  height: 100%;
  min-height: 200px;
  padding-bottom: var(--space-medium);
}

.kanban-column {
  flex: 0 0 320px;
  display: flex;
  flex-direction: column;
  background-color: var(--white);
  border-radius: var(--border-radius-normal);
  box-shadow: var(--shadow-small);
  border: 1px solid var(--s-100);
  overflow: hidden;
}

.column-header {
  padding: var(--space-normal);
  font-weight: var(--font-weight-medium);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: var(--s-50);
  border-top: 4px solid;
  cursor: move;
  position: relative;
  
  .column-title {
    font-size: var(--font-size-normal);
  }
  
  .column-count {
    font-size: var(--font-size-small);
    background-color: var(--s-200);
    color: var(--s-800);
    border-radius: var(--border-radius-rounded);
    padding: 2px 8px;
    
    .dark-mode & {
      background-color: var(--b-600);
      color: var(--s-200);
    }
  }
}

.column-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-small);
}

.column-items {
  min-height: 100px;
  display: flex;
  flex-direction: column;
  gap: var(--space-normal);
}

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
  padding: 6px;
  font-size: 18px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--border-radius-small);
  background-color: var(--white);
  border: 1px solid var(--s-200);
  box-shadow: var(--shadow-small);

  &:hover {
    background-color: var(--s-100);
  }

  &.view-icon {
    color: var(--b-500);
  }

  &.remove-icon {
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

.empty-column {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100px;
  
  p {
    color: var(--s-500);
    font-size: var(--font-size-small);
  }
}

.ghost-card {
  opacity: 0.5;
  background: var(--w-50);
  
  .dark-mode & {
    background: var(--b-600);
  }
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

.search-box {
  width: 200px;
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
</style> 