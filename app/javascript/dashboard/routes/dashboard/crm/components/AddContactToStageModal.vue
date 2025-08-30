<template>
  <woot-modal
    :show.sync="show"
    :on-close="onClose"
  >
    <div class="h-auto overflow-auto flex flex-col">
      <woot-modal-header
        :header-title="$t('KANBAN.ADD_CONTACT.TITLE')"
        :header-content="$t('KANBAN.ADD_CONTACT.DESC', { stage: selectedStage })"
      >
        <!-- Badge da etapa -->
        <div class="mt-3">
          <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-woot-500 text-white">
            {{ selectedStage }}
          </span>
        </div>
      </woot-modal-header>

      <!-- Busca de contatos -->
      <div class="px-8 pt-4">
        <div class="search-container">
          <fluent-icon icon="search" size="16" class="search-icon" />
          <input
            v-model="searchQuery"
            type="text"
            :placeholder="$t('KANBAN.SEARCH_PLACEHOLDER')"
            class="search-input"
            @input="onInputSearch"
            @search="resetSearch"
            :disabled="isLoading"
          />
          <!-- Loading spinner -->
          <div v-if="isLoading" class="absolute inset-y-0 right-0 pr-3 flex items-center">
            <div class="animate-spin w-5 h-5 border-2 border-woot-500 border-t-transparent rounded-full"></div>
          </div>
        </div>
      </div>

              <!-- Lista de contatos -->
        <div class="px-8 pt-4 pb-6">
          
          <div v-if="isLoading && localContacts.length === 0" class="loading-state">
            <woot-loading-state :message="$t('KANBAN.LOADING_CONTACTS')" />
          </div>
          
          <div v-else-if="showEmptySearchResult" class="empty-state">
            <fluent-icon icon="people" size="48" class="empty-icon" />
            <p class="empty-text">{{ $t('KANBAN.NO_CONTACTS_TO_ADD') }}</p>
          </div>
          
          <div v-else class="contacts-list">
            <div
              v-for="contact in filteredContacts"
              :key="contact.id"
              class="contact-item"
              :class="{ 'already-in-kanban': isContactInKanban(contact) }"
              @click="selectContact(contact)"
            >
              <div class="contact-info">
                <woot-thumbnail
                  :src="contact.avatar_url"
                  :username="contact.name"
                  size="32px"
                  class="contact-avatar"
                />
                <div class="contact-details">
                  <div class="contact-name">{{ contact.name }}</div>
                  <div v-if="contact.email" class="contact-email">{{ contact.email }}</div>
                  <div v-if="contact.phone_number" class="contact-phone">{{ contact.phone_number }}</div>
                </div>
              </div>
              
              <div class="contact-status">
                <span v-if="isContactInKanban(contact)" class="status-badge already-added">
                  {{ $t('KANBAN.ALREADY_IN_KANBAN') }}
                </span>
                <fluent-icon v-else icon="add" size="16" class="add-icon" />
              </div>
            </div>
          </div>
        </div>

      <!-- Footer com contador -->
      <div class="flex flex-row justify-between items-center gap-2 py-4 px-8 w-full border-t border-slate-200 dark:border-slate-800">
        <div class="text-sm text-slate-600 dark:text-slate-400">
          {{ filteredContacts.length }} {{ $t('KANBAN.CONTACTS_FOUND') }}
        </div>
        <div class="flex items-center gap-2">
                                <woot-button variant="clear" @click="onClose">
                        {{ $t('COMMON.CANCEL') }}
                      </woot-button>
        </div>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import debounce from 'lodash/debounce';

const DEFAULT_PAGE = 1;

export default {
  name: 'AddContactToStageModal',
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    selectedStage: {
      type: String,
      default: '',
    },
    pipelineId: {
      type: [String, Number],
      required: true,
    },
    attributeKey: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      searchQuery: '',
      localContacts: [],
      contactsMeta: {
        count: 0,
        currentPage: 1,
      },
      isLoading: false,
      searchTimeout: null,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
    }),
    filteredContacts() {
      // Usar contatos locais em vez do store global
      if (!this.searchQuery.trim()) {
        return this.localContacts;
      }
      
      const query = this.searchQuery.toLowerCase();
      return this.localContacts.filter(contact => {
        const name = contact.name ? contact.name.toLowerCase() : '';
        const email = contact.email ? contact.email.toLowerCase() : '';
        const phone = contact.phone_number ? contact.phone_number.toLowerCase() : '';
        
        return name.includes(query) || 
               email.includes(query) || 
               phone.includes(query);
      });
    },
    showEmptySearchResult() {
      return !this.isLoading && this.filteredContacts.length === 0 && this.searchQuery.trim();
    },
  },
  watch: {
    show(newVal) {
      if (newVal) {
        // Carregar contatos imediatamente ao abrir
        this.$nextTick(() => {
          this.fetchContacts(DEFAULT_PAGE);
        });
      } else {
        this.resetModal();
      }
    },
  },
  mounted() {
    // Garantir que os contatos sejam carregados se o modal já estiver aberto
    if (this.show) {
      this.fetchContacts(DEFAULT_PAGE);
    }
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    resetModal() {
      this.searchQuery = '';
      this.localContacts = [];
    },
    async fetchContacts(page = DEFAULT_PAGE) {
      this.isLoading = true;
      
      try {
        let value = this.searchQuery.trim();
        if (value && value.charAt(0) === '+') {
          value = value.substring(1);
        }

        const requestParams = {
          page,
          sortAttr: '-last_activity_at',
        };

        let response;
        if (!value) {
          // Buscar contatos diretamente via API sem afetar o store global
          response = await ContactAPI.get(page, requestParams.sortAttr);
        } else {
          // Buscar contatos com query diretamente via API
          response = await ContactAPI.search(
            encodeURIComponent(value),
            page,
            requestParams.sortAttr
          );
        }

        // Armazenar no estado local em vez do store global
        this.localContacts = response.data.payload || [];
        this.contactsMeta = response.data.meta || { count: 0, currentPage: 1 };
        

      } catch (error) {

        useAlert(this.$t('KANBAN.ERRORS.FETCH_CONTACTS_FAILED'));
        this.localContacts = [];
      } finally {
        this.isLoading = false;
      }
    },
    onInputSearch: debounce(function(event) {
      this.searchQuery = event.target.value;
      this.fetchContacts();
    }, 300),
    
    resetSearch(event) {
      const newQuery = event.target.value;
      if (!newQuery) {
        this.searchQuery = '';
        this.fetchContacts();
      }
    },
    isContactInKanban(contact) {
      const customAttributes = contact.custom_attributes || {};
      return customAttributes[this.attributeKey] === this.selectedStage;
    },
    async selectContact(contact) {
      // Se já está no kanban nesta etapa, não fazer nada
      if (this.isContactInKanban(contact)) {
        return;
      }

      try {
        // Criar estrutura do kanban para o contato
        const now = new Date().toISOString();
        
        const kanbanData = {
          [this.pipelineId]: {
            stage_tracking: {
              current: {
                stage_id: this.selectedStage,
                entered_at: now,
              },
            },
          },
        };

        const contactParams = {
          id: contact.id,
          custom_attributes: {
            ...contact.custom_attributes,
            [this.attributeKey]: this.selectedStage,
          },
          additional_attributes: {
            ...contact.additional_attributes,
            kanban: kanbanData,
          },
        };

        await this.$store.dispatch('contacts/update', contactParams);
        
        this.$emit('contact-added', {
          contact,
          stage: this.selectedStage,
          pipelineId: this.pipelineId,
        });
        
        this.onClose();
      } catch (error) {

        useAlert(this.$t('KANBAN.ERRORS.ADD_CONTACT_FAILED'));
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.search-container {
  position: relative;
  margin-bottom: var(--space-normal);
}

.search-input {
  width: 100%;
  padding: var(--space-small) var(--space-small) var(--space-small) 2.5rem;
  padding-right: 3rem; /* Espaço para o spinner */
  border: 1px solid var(--s-200);
  border-radius: var(--border-radius-normal);
  font-size: var(--font-size-small);
  
  &:focus {
    outline: none;
    border-color: var(--woot-color-woot-500);
    box-shadow: 0 0 0 3px rgba(var(--woot-color-woot-500-rgb), 0.1);
  }
  
  .dark-mode & {
    background-color: var(--b-700);
    border-color: var(--b-600);
    color: var(--s-100);
  }
}

.search-icon {
  position: absolute;
  left: var(--space-small);
  top: 50%;
  transform: translateY(-50%);
  color: var(--s-400);
}



.loading-state {
  display: flex;
  justify-content: center;
  padding: var(--space-large);
}

.empty-state {
  text-align: center;
  padding: var(--space-large);
  color: var(--s-500);
  
  .empty-icon {
    margin-bottom: var(--space-normal);
    opacity: 0.5;
  }
  
  .empty-text {
    margin: 0;
    font-size: var(--font-size-small);
  }
}

.contacts-list {
  max-height: 400px;
  overflow-y: auto;
}

.contact-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-small);
  border-radius: var(--border-radius-normal);
  cursor: pointer;
  transition: background-color 0.2s ease;
  
  &:hover:not(.already-in-kanban) {
    background-color: var(--s-50);
    
    .dark-mode & {
      background-color: var(--b-700);
    }
  }
  
  &.already-in-kanban {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.contact-info {
  display: flex;
  align-items: center;
  gap: var(--space-small);
  flex: 1;
}

.contact-avatar {
  flex-shrink: 0;
}

.contact-details {
  flex: 1;
  min-width: 0;
}

.contact-name {
  font-weight: var(--font-weight-medium);
  color: var(--s-800);
  margin-bottom: 2px;
  
  .dark-mode & {
    color: var(--s-100);
  }
}

.contact-email,
.contact-phone {
  font-size: var(--font-size-mini);
  color: var(--s-500);
  
  .dark-mode & {
    color: var(--s-400);
  }
}

.contact-status {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
}

.status-badge {
  font-size: var(--font-size-mini);
  padding: 2px 8px;
  border-radius: var(--border-radius-rounded);
  font-weight: var(--font-weight-medium);
  
  &.already-added {
    background-color: var(--s-200);
    color: var(--s-600);
    
    .dark-mode & {
      background-color: var(--b-600);
      color: var(--s-300);
    }
  }
}

.add-icon {
  color: var(--woot-color-woot-500);
  opacity: 0.7;
  transition: opacity 0.2s ease;
}

.contact-item:hover .add-icon {
  opacity: 1;
}
</style>
