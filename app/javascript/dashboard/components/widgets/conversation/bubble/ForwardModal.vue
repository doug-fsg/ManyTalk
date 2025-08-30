<template>
  <woot-modal
    modal-type="right-aligned"
    show
    :on-close="onClose"
    :should-close-on-outside-click="false"
    :should-close-on-escape="true"
  >
    <div class="h-auto overflow-auto flex flex-col max-w-[50rem]">
      <!-- Header usando componente padrão -->
      <woot-modal-header
        header-title="Encaminhar mensagem"
        header-content="Selecione os contatos para encaminhar esta mensagem"
      >
        <!-- Contador de selecionados -->
        <div v-if="selectedContacts.length > 0" class="mt-3">
          <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-woot-500 text-white">
            {{ selectedContacts.length }} selecionado{{ selectedContacts.length > 1 ? 's' : '' }}
          </span>
        </div>
      </woot-modal-header>

      <!-- Formulário de busca e conteúdo -->
      <form @submit.prevent="onSubmit" class="modal-content flex flex-col h-full">
        <!-- Campo de busca -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            Procurar contatos
          </label>
          <div class="relative">
            <input
              type="search"
              v-model="searchQuery"
              @input="onInputSearch"
              @search="resetSearch"
              placeholder="Buscar por nome, email ou telefone..."
              :disabled="isLoading"
              class="w-full px-4 py-3 pl-10 border border-slate-300 dark:border-slate-700 rounded-lg
                     focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500
                     bg-white dark:bg-slate-800 text-slate-900 dark:text-white
                     hover:border-woot-500 transition-colors"
            >
            <!-- Ícone de busca -->
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <fluent-icon icon="search" size="20" class="text-slate-400" />
            </div>
            <!-- Loading spinner -->
            <div v-if="isLoading" class="absolute inset-y-0 right-0 pr-3 flex items-center">
              <div class="animate-spin w-5 h-5 border-2 border-woot-500 border-t-transparent rounded-full"></div>
            </div>
          </div>
        </div>

        <!-- Lista de contatos -->
        <div class="flex-1 overflow-hidden flex flex-col">
          <!-- Cabeçalho da tabela -->
          <div class="flex items-center px-4 py-3 bg-slate-50 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
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
            <div class="flex-1 text-sm font-medium text-slate-700 dark:text-slate-300">
              Contato
            </div>
            <div class="w-32 text-sm font-medium text-slate-700 dark:text-slate-300">
              Telefone
            </div>
          </div>

          <!-- Conteúdo da lista -->
          <div class="flex-1 overflow-y-auto">
            <!-- Loading state -->
            <div v-if="isLoading && localContacts.length === 0" class="flex items-center justify-center py-12">
              <div class="text-center">
                <div class="animate-spin w-8 h-8 border-2 border-woot-500 border-t-transparent rounded-full mx-auto mb-3"></div>
                <p class="text-slate-600 dark:text-slate-400">Carregando contatos...</p>
              </div>
            </div>

            <!-- Empty state -->
            <div v-else-if="showEmptySearchResult" class="flex items-center justify-center py-12">
              <div class="text-center">
                <fluent-icon icon="people" size="48" class="text-slate-400 mx-auto mb-3" />
                <h3 class="text-lg font-medium text-slate-900 dark:text-white mb-1">Nenhum contato encontrado</h3>
                <p class="text-slate-600 dark:text-slate-400">Tente ajustar sua busca ou adicione novos contatos.</p>
              </div>
            </div>

            <!-- Lista de contatos -->
            <div v-else class="divide-y divide-slate-200 dark:divide-slate-700">
              <div
                v-for="contact in filteredContacts"
                :key="contact.id"
                class="flex items-center px-4 py-3 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors cursor-pointer"
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
                <div class="flex-1 flex items-center">
                  <!-- Avatar do contato -->
                  <div v-if="contact.thumbnail" class="w-8 h-8 mr-3 flex-shrink-0">
                    <img
                      :src="contact.thumbnail"
                      :alt="contact.name"
                      class="w-full h-full rounded-full object-cover"
                    >
                  </div>
                  <div v-else class="w-8 h-8 mr-3 flex-shrink-0 bg-woot-500 rounded-full flex items-center justify-center">
                    <span class="text-xs font-medium text-white">
                      {{ getInitials(contact.name) }}
                    </span>
                  </div>
                  <!-- Info do contato -->
                  <div class="min-w-0 flex-1">
                    <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                      {{ contact.name || 'Sem nome' }}
                    </p>
                    <p v-if="contact.email" class="text-xs text-slate-500 dark:text-slate-400 truncate">
                      {{ contact.email }}
                    </p>
                  </div>
                </div>
                <div class="w-32 text-sm text-slate-600 dark:text-slate-400 truncate">
                  {{ contact.phone_number || 'Sem telefone' }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer com botões de ação -->
        <div class="flex flex-row justify-between items-center gap-2 py-4 px-8 w-full border-t border-slate-200 dark:border-slate-800">
          <div class="text-sm text-slate-600 dark:text-slate-400">
            {{ filteredContacts.length }} contato{{ filteredContacts.length !== 1 ? 's' : '' }} encontrado{{ filteredContacts.length !== 1 ? 's' : '' }}
          </div>
          <div class="flex items-center gap-2">
            <woot-button
              type="submit"
              :disabled="selectedContacts.length === 0 || isForwarding"
              :loading="isForwarding"
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
import { useAlert } from 'dashboard/composables';
import debounce from 'lodash/debounce';
import ContactAPI from 'dashboard/api/contacts';

const DEFAULT_PAGE = 1;

export default {
  props: {
    message: {
      type: Object,
      required: true,
      validator(value) {
        return value && value.id && value.conversation_id;
      }
    }
  },
      data() {
    return {
      searchQuery: '',
      selectedContacts: [],
      isLoading: false,
      isForwarding: false,
      // Estado local para contatos - não afeta o store global
      localContacts: [],
      contactsMeta: {
        count: 0,
        currentPage: 1,
      },
    }
  },
      computed: {
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
        console.error('Erro ao carregar contatos:', error);
        useAlert('Erro ao carregar contatos. Tente novamente.');
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
      if (this.selectedContacts.length === 0) {
        useAlert('Selecione pelo menos um contato para encaminhar a mensagem.');
        return;
      }
      
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

        const contactCount = this.selectedContacts.length;
        const successMessage = `Mensagem encaminhada para ${contactCount} contato${contactCount > 1 ? 's' : ''}!`;
        useAlert(successMessage);
        this.onClose();
      } catch (error) {
        console.error('Erro ao encaminhar mensagem:', error);
        useAlert('Erro ao encaminhar mensagem. Tente novamente.');
      } finally {
        this.isForwarding = false;
      }
    }
    }
}
</script>

<style lang="scss" scoped>
// Estilo para checkbox indeterminate
input[type="checkbox"]:indeterminate {
  background-color: var(--woot-color-woot-500);
  border-color: var(--woot-color-woot-500);
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
</style>