<template>
    <woot-modal
        modal-type="right-aligned"
        show
        :on-close="onClose"
    :should-close-on-outside-click="false"
    :should-close-on-escape="true"
  >
    <div 
      class="fixed inset-y-0 right-0 max-h-screen overflow-auto bg-white shadow-md modal-container rtl:text-right dark:bg-slate-900 skip-context-menu rounded-xl w-[50rem] z-50"
      @mouseleave.stop
      @mouseenter.stop
    >
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-800">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-lg font-semibold text-slate-900 dark:text-white">
              Compartilhar mensagem
            </h1>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Compartilhe a mensagem com seus contatos
            </p>
          </div>
          <!-- Contador de selecionados -->
          <div v-if="selectedContacts.length > 0" class="bg-woot-500 text-white px-3 py-1 rounded-full text-sm font-medium">
            {{ selectedContacts.length }} selecionado{{ selectedContacts.length > 1 ? 's' : '' }}
          </div>
        </div>
            </div>

      <!-- Search -->
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-800">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          Procurar um contato
        </label>
        <div class="relative">
                        <input
                            type="search"
            class="w-full px-4 py-3 border border-slate-300 dark:border-slate-700 rounded-lg
                   focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500
                   bg-white dark:bg-slate-800 text-slate-900 dark:text-white
                   hover:border-woot-500 transition-colors pl-10"
                            v-model="searchQuery"
                            @input="onInputSearch"
                            @search="resetSearch"
            placeholder="Buscar por nome ou telefone..."
            :disabled="isLoading"
          >
          <!-- Ícone de busca -->
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg class="w-5 h-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </div>
          <!-- Loading spinner -->
          <div v-if="isLoading" class="absolute inset-y-0 right-0 pr-3 flex items-center">
            <svg class="animate-spin w-5 h-5 text-woot-500" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
        </div>
      </div>

      <!-- Contacts List -->
      <form @submit.prevent="onSubmit" class="flex-1 flex flex-col min-h-0">
        <!-- Table Header -->
        <div class="px-6 py-3 bg-slate-50 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
          <div class="flex items-center text-sm font-medium text-slate-700 dark:text-slate-300">
            <div class="w-8 flex items-center">
              <!-- Checkbox para selecionar todos -->
              <input
                type="checkbox"
                :checked="isAllSelected"
                :indeterminate="isIndeterminate"
                @change="toggleSelectAll"
                class="w-4 h-4 rounded border-slate-300 dark:border-slate-600
                       text-woot-500 focus:ring-woot-500/20"
                :disabled="filteredContacts.length === 0"
              >
            </div>
            <div class="flex-1 min-w-[200px]">Contato</div>
            <div class="w-40">Telefone</div>
          </div>
        </div>

        <!-- Table Body -->
        <div class="flex-1 overflow-y-auto min-h-0">
          <!-- Loading state -->
          <div v-if="isLoading && contacts.length === 0" class="flex items-center justify-center py-12">
            <div class="text-center">
              <svg class="animate-spin w-8 h-8 text-woot-500 mx-auto mb-3" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <p class="text-slate-600 dark:text-slate-400">Carregando contatos...</p>
            </div>
          </div>

          <!-- Empty state -->
          <div v-else-if="showEmptySearchResult" class="flex items-center justify-center py-12">
            <div class="text-center">
              <svg class="w-12 h-12 text-slate-400 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <h3 class="text-lg font-medium text-slate-900 dark:text-white mb-1">Nenhum contato encontrado</h3>
              <p class="text-slate-600 dark:text-slate-400">Tente ajustar sua busca ou adicione novos contatos.</p>
            </div>
          </div>

          <!-- Contacts list -->
          <div v-else class="divide-y divide-slate-200 dark:divide-slate-700">
            <div
              v-for="contact in filteredContacts"
              :key="contact.id"
              class="flex items-center px-6 py-3 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors cursor-pointer"
              @click="toggleContact(contact.id)"
            >
              <div class="w-8">
                <input
                  type="checkbox"
                  :value="contact.id"
                  v-model="selectedContacts"
                  class="w-4 h-4 rounded border-slate-300 dark:border-slate-600
                         text-woot-500 focus:ring-woot-500/20 cursor-pointer"
                  @click.stop
                        >
                    </div>
              <div class="flex-1 min-w-[200px] flex items-center">
                <div v-if="contact.thumbnail" class="w-8 h-8 mr-3 flex-shrink-0">
                  <img
                    :src="contact.thumbnail"
                    :alt="contact.name"
                    class="w-full h-full rounded-full object-cover border-2 border-slate-200 dark:border-slate-700"
                  >
                </div>
                <div v-else class="w-8 h-8 mr-3 flex-shrink-0 bg-slate-300 dark:bg-slate-600 rounded-full flex items-center justify-center">
                  <span class="text-xs font-medium text-slate-700 dark:text-slate-300">
                    {{ getInitials(contact.name) }}
                  </span>
                        </div>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium text-slate-900 dark:text-white truncate">{{ contact.name }}</p>
                  <p v-if="contact.email" class="text-xs text-slate-500 dark:text-slate-400 truncate">{{ contact.email }}</p>
                                </div>
                                    </div>
              <div class="w-40 text-sm text-slate-600 dark:text-slate-400 truncate">
                {{ contact.phone_number || 'Sem telefone' }}
                                </div>
                            </div>
                        </div>
                    </div>

        <!-- Footer -->
        <div class="px-6 py-4 bg-white dark:bg-slate-900 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between">
          <div class="text-sm text-slate-600 dark:text-slate-400">
            {{ filteredContacts.length }} contato{{ filteredContacts.length !== 1 ? 's' : '' }} encontrado{{ filteredContacts.length !== 1 ? 's' : '' }}
                    </div>
          <div class="flex space-x-3">
            <woot-button
              type="button"
              variant="clear"
              @click="onClose"
              class="px-4 py-2"
            >
              Cancelar
            </woot-button>
            <woot-button
              :disabled="selectedContacts.length === 0 || isForwarding"
              :loading="isForwarding"
              class="bg-woot-500 hover:bg-woot-600 text-white px-6 py-2"
            >
              <span v-if="!isForwarding">
                Encaminhar{{ selectedContacts.length > 0 ? ` (${selectedContacts.length})` : '' }}
              </span>
              <span v-else>Encaminhando...</span>
            </woot-button>
            </div>
        </div>
      </form>
        </div>
    </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import debounce from 'lodash/debounce';

const DEFAULT_PAGE = 1;

export default {
    props: {
        message: {
      type: Object,
      required: true
        }
    },
    data() {
        return {
            searchQuery: '',
      selectedContacts: [],
      isLoading: false,
      isForwarding: false,
        }
    },
    computed: {
        ...mapGetters({
            contacts: 'contacts/getContacts',
        }),
    filteredContacts() {
      if (!this.searchQuery.trim()) {
        return this.contacts;
      }
      return this.contacts;
    },
        showEmptySearchResult() {
      return !this.isLoading && this.filteredContacts.length === 0 && this.searchQuery.trim();
    },
    isAllSelected() {
      return this.filteredContacts.length > 0 && 
             this.selectedContacts.length === this.filteredContacts.length;
    },
    isIndeterminate() {
      return this.selectedContacts.length > 0 && 
             this.selectedContacts.length < this.filteredContacts.length;
        },
    },
    mounted() {
        this.fetchContacts(DEFAULT_PAGE);
    },
    methods: {
        onClose() {
            this.$emit('close');
        },
        updatePageParam(page) {
            window.history.pushState({}, null, `${this.$route.path}?page=${page}`);
        },
    async fetchContacts(page) {
      this.isLoading = true;
            this.updatePageParam(page);
      
      try {
            let value = this.searchQuery;
            if (this.searchQuery.charAt(0) === '+') {
                value = this.searchQuery.substring(1);
            }

            const requestParams = {
                page,
                sortAttr: '-last_activity_at',
            };

            if (!value) {
          await this.$store.dispatch('contacts/get', requestParams);
            } else {
          await this.$store.dispatch('contacts/search', {
                    search: encodeURIComponent(value),
                    ...requestParams,
                });
        }
      } catch (error) {
        useAlert('Erro ao carregar contatos. Tente novamente.');
      } finally {
        this.isLoading = false;
      }
    },
    onInputSearch: debounce(function(event) {
            const newQuery = event.target.value;
            this.searchQuery = newQuery;
                this.fetchContacts(DEFAULT_PAGE);
    }, 300),
        resetSearch(event) {
            const newQuery = event.target.value;
            if (!newQuery) {
                this.searchQuery = newQuery;
                this.fetchContacts(DEFAULT_PAGE);
            }
        },
    toggleContact(contactId) {
      const index = this.selectedContacts.indexOf(contactId);
      if (index > -1) {
        this.selectedContacts.splice(index, 1);
      } else {
        this.selectedContacts.push(contactId);
      }
    },
    toggleSelectAll() {
      if (this.isAllSelected) {
        this.selectedContacts = [];
      } else {
        this.selectedContacts = this.filteredContacts.map(contact => contact.id);
      }
    },
    getInitials(name) {
      if (!name) return '?';
      return name
        .split(' ')
        .map(word => word.charAt(0))
        .join('')
        .slice(0, 2)
        .toUpperCase();
    },
    async onSubmit() {
      if (this.selectedContacts.length === 0) return;
      
      this.isForwarding = true;
      
              try {
          // Buscar conversas dos contatos para priorizar conversas abertas
          const activeConversations = {};
          
          for (const contactId of this.selectedContacts) {
            try {
              await this.$store.dispatch('contactConversations/get', contactId);
              const conversations = this.$store.getters['contactConversations/getContactConversation'](contactId);
              
              // Procurar por conversa aberta (status open)
              const openConversation = conversations.find(conv => conv.status === 'open');
              if (openConversation) {
                activeConversations[contactId] = openConversation.id;
              }
            } catch (error) {
              // Se falhar ao buscar conversas, continua sem priorizar
              console.warn(`Erro ao buscar conversas do contato ${contactId}:`, error);
            }
          }

          await this.$store.dispatch('forwardMessage', {
                conversationId: this.message.conversation_id,
                messageId: this.message.id,
            contacts: this.selectedContacts,
            activeConversations
            });

        useAlert(`Mensagem encaminhada para ${this.selectedContacts.length} contato${this.selectedContacts.length > 1 ? 's' : ''}!`);
            this.onClose();
      } catch (error) {
        useAlert('Erro ao encaminhar mensagem. Tente novamente.');
      } finally {
        this.isForwarding = false;
      }
        }
    }
}
</script>

<style lang="scss">
.modal-mask .modal--close {
  z-index: 51;
}

.modal-container {
  animation: slideIn 0.3s ease-out;
}

@keyframes slideIn {
  from {
    transform: translateX(100%);
  }
  to {
    transform: translateX(0);
  }
}

// Estilo para checkbox indeterminate
input[type="checkbox"]:indeterminate {
  background-color: var(--woot-color-primary);
  border-color: var(--woot-color-primary);
  position: relative;
  
  &::after {
    content: '';
            position: absolute;
    top: 50%;
    left: 50%;
    width: 8px;
    height: 2px;
    background: white;
    transform: translate(-50%, -50%);
  }
}

// Melhoria na experiência de hover para linhas clicáveis
.cursor-pointer:hover {
  transform: translateY(-1px);
  transition: transform 0.1s ease-in-out;
}
</style>