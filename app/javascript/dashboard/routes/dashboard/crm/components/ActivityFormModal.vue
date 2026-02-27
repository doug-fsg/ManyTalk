<template>
  <div class="h-auto overflow-auto flex flex-col">
    <woot-modal-header
      :header-title="$t(activity ? 'ACTIVITIES.EDIT' : 'ACTIVITIES.CREATE')"
    />
    <form class="flex flex-col w-full space-y-4" @submit.prevent="handleSubmit">
      <div class="w-full space-y-4">

        <!-- Seletor de Contato (apenas quando contactId não é fornecido) -->
        <div v-if="showContactSelector" class="space-y-2">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ $t('ACTIVITIES.FORM.CONTACT') }} *
          </label>
          <div v-if="selectedContact" class="flex items-center justify-between px-3 py-2 bg-slate-50 dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700">
            <div class="flex items-center gap-2">
              <woot-thumbnail
                :src="selectedContact.thumbnail || selectedContact.avatar_url"
                :username="selectedContact.name"
                size="28px"
              />
              <div>
                <div class="text-sm font-medium text-slate-900 dark:text-white">{{ selectedContact.name }}</div>
                <div v-if="selectedContact.email || selectedContact.phone_number" class="text-xs text-slate-500 dark:text-slate-400">
                  {{ selectedContact.email || selectedContact.phone_number }}
                </div>
              </div>
            </div>
            <woot-button
              variant="clear"
              size="tiny"
              icon="edit"
              @click="clearSelectedContact"
            />
          </div>
          <div v-else>
            <div class="relative">
              <input
                ref="contactSearchInput"
                v-model="contactSearchQuery"
                type="text"
                :placeholder="$t('ACTIVITIES.FORM.SEARCH_CONTACT_PLACEHOLDER')"
                class="w-full px-3 py-2 pr-10 border border-slate-200 dark:border-slate-600 rounded-md text-sm dark:bg-slate-900 dark:text-white focus:outline-none focus:border-woot-500 dark:focus:border-woot-600"
                @input="onContactSearchInput"
              />
              <div v-if="isSearchingContacts" class="absolute right-3 top-1/2 -translate-y-1/2">
                <i class="icon-refresh animate-spin text-slate-400" />
              </div>
            </div>
            <p v-if="contactSearchError" class="mt-1 text-xs text-red-600 dark:text-red-400">{{ contactSearchError }}</p>
            <div v-if="contactSearchQuery.trim() && filteredContacts.length > 0" class="mt-2 max-h-32 overflow-y-auto border border-slate-200 dark:border-slate-700 rounded-lg divide-y divide-slate-200 dark:divide-slate-700">
              <div
                v-for="contact in filteredContacts"
                :key="contact.id"
                class="flex items-center gap-2 px-2 py-1.5 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
                @click="selectContact(contact)"
              >
                <woot-thumbnail
                  :src="contact.thumbnail || contact.avatar_url"
                  :username="contact.name"
                  size="24px"
                />
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-medium text-slate-900 dark:text-white truncate">{{ contact.name }}</div>
                  <div v-if="contact.email || contact.phone_number" class="text-[11px] text-slate-500 dark:text-slate-400 truncate">
                    {{ contact.email || contact.phone_number }}
                  </div>
                </div>
              </div>
            </div>
            <p v-else-if="contactSearchQuery.trim() && !isSearchingContacts && localContacts.length === 0" class="mt-2 text-xs text-slate-500 dark:text-slate-400">
              {{ $t('ACTIVITIES.FORM.NO_CONTACTS_FOUND') }}
            </p>
          </div>
        </div>

        <!-- Type -->
        <label>
          {{ $t('ACTIVITIES.FORM.TYPE_LABEL') }}
          <select v-model="form.activity_type" class="mt-2">
            <option value="task">{{ $t('ACTIVITIES.TYPE.TASK') }}</option>
            <option value="scheduled_message">{{ $t('ACTIVITIES.TYPE.SCHEDULED_MESSAGE') }}</option>
          </select>
        </label>

        <!-- Title e Description (apenas para Tarefa) -->
        <template v-if="form.activity_type === 'task'">
          <woot-input
            v-model="form.title"
            :label="$t('ACTIVITIES.FORM.TITLE')"
            type="text"
            required
            :placeholder="$t('ACTIVITIES.FORM.TITLE_PLACEHOLDER')"
          />
          <label>
            {{ $t('ACTIVITIES.FORM.DESCRIPTION') }}
            <textarea
              v-model="form.description"
              rows="2"
              class="mt-2"
            />
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Adicione detalhes opcionais sobre esta atividade</p>
          </label>
        </template>

        <!-- Seção de Mensagem Agendada -->
        <div v-if="showMessageFields" class="space-y-4">
          <!-- Inbox Selection -->
          <label>
            {{ $t('ACTIVITIES.FORM.INBOX') }}
            <select v-model="form.inbox_id" required class="mt-2">
              <option value="">{{ $t('ACTIVITIES.FORM.SELECT_INBOX') }}</option>
              <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
                {{ inbox.name }}
              </option>
            </select>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Escolha o canal por onde a mensagem será enviada</p>
          </label>

          <!-- Message Content -->
          <div class="editor-wrap">
            <label>
              {{ $t('ACTIVITIES.FORM.MESSAGE_CONTENT') }}
            </label>
            <div class="mt-2">
              <woot-message-editor
                v-model="form.message_content"
                class="message-editor"
                :placeholder="$t('ACTIVITIES.FORM.MESSAGE_PLACEHOLDER')"
              />
            </div>
            <p class="mt-2 text-[11px] text-slate-500 dark:text-slate-400">
              {{ $t('ACTIVITIES.FORM.SCHEDULED_MESSAGE_FOOTER') }}
            </p>
          </div>
        </div>

        <!-- Quando (no final) -->
        <div>
          <label>
            {{ $t('ACTIVITIES.FORM.SCHEDULED_AT') }}
            <input
              v-model="form.scheduled_at"
              type="datetime-local"
              required
              class="mt-2"
            />
          </label>
          <div v-if="formattedScheduledDate" class="mt-2 px-3 py-2 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
            <p class="text-xs text-blue-700 dark:text-blue-300 flex items-center gap-1">
              <fluent-icon icon="info" size="12" />
              {{ formattedScheduledDate }}
            </p>
          </div>
        </div>

      </div>

      <!-- Actions -->
      <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
        <woot-button type="submit" color-scheme="primary">
          {{ $t('ACTIVITIES.FORM.SUBMIT') }}
        </woot-button>
        <woot-button variant="clear" @click.prevent="$emit('cancel')">
          {{ $t('ACTIVITIES.FORM.CANCEL') }}
        </woot-button>
      </div>
    </form>
  </div>
</template>

<script>
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import WootThumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import ContactAPI from 'dashboard/api/contacts';
import debounce from 'lodash/debounce';

const DEFAULT_PAGE = 1;

export default {
  components: {
    FluentIcon,
    WootMessageEditor,
    WootThumbnail,
  },
  props: {
    activity: {
      type: Object,
      default: null,
    },
    contactId: {
      type: Number,
      default: null,
    },
    pipelineId: {
      type: [Number, String],
      default: null,
    },
  },
  computed: {
    showContactSelector() {
      return this.contactId == null;
    },
    effectiveContactId() {
      if (this.contactId != null) return this.contactId;
      return this.selectedContact?.id ?? null;
    },
    filteredContacts() {
      if (!this.contactSearchQuery.trim()) return this.localContacts;
      const query = this.contactSearchQuery.toLowerCase();
      return this.localContacts.filter(c => {
        const name = (c.name || '').toLowerCase();
        const email = (c.email || '').toLowerCase();
        const phone = (c.phone_number || '').toLowerCase();
        return name.includes(query) || email.includes(query) || phone.includes(query);
      });
    },
    inboxes() {
      // Retornar todos os inboxes disponíveis (SMS e API)
      // Garantir que sempre retornamos um array, mesmo se os getters retornarem undefined
      const smsInboxes = this.$store.getters['inboxes/getSMSInboxes'] || [];
      const apiInboxes = this.$store.getters['inboxes/getApiInboxes'] || [];
      return [...smsInboxes, ...apiInboxes];
    },
    formattedScheduledDate() {
      if (!this.form.scheduled_at) return '';
      
      const date = new Date(this.form.scheduled_at);
      const now = new Date();
      
      // Resetar horas para comparação de dias
      const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const targetDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
      const daysDiff = Math.floor((targetDate - nowDate) / (1000 * 60 * 60 * 24));
      
      const timeString = date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
      
      if (daysDiff === 0) {
        return `Será executada hoje às ${timeString}`;
      } else if (daysDiff === 1) {
        return `Será executada amanhã às ${timeString}`;
      } else if (daysDiff === -1) {
        return `Estava agendada para ontem às ${timeString}`;
      } else if (daysDiff < 0) {
        return `Estava agendada para ${Math.abs(daysDiff)} dias atrás`;
      } else {
        const dateString = date.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' });
        return `Será executada em ${dateString} às ${timeString}`;
      }
    },
    showMessageFields() {
      return this.form.activity_type === 'scheduled_message';
    },
  },
  data() {
    return {
      form: {
        activity_type: 'task',
        title: '',
        description: '',
        scheduled_at: '',
        message_content: '',
        inbox_id: '',
      },
      contactSearchQuery: '',
      localContacts: [],
      selectedContact: null,
      isSearchingContacts: false,
      contactSearchError: '',
    };
  },
  watch: {
    'form.activity_type'(newVal) {
      if (newVal === 'task') {
        this.form.inbox_id = '';
      } else if (newVal === 'scheduled_message') {
        this.form.title = '';
        this.form.description = '';
      }
    },
  },
  async mounted() {
    // Carregar inboxes se ainda não foram carregados
    await this.$store.dispatch('inboxes/get');

    if (this.activity) {
      this.form = { ...this.activity };
      if (this.form.scheduled_at) {
        const date = new Date(this.form.scheduled_at);
        this.form.scheduled_at = date.toISOString().slice(0, 16);
      }
    } else {
      // Auto-selecionar se houver apenas um inbox
      this.$nextTick(() => {
        if (this.inboxes.length === 1) {
          this.form.inbox_id = this.inboxes[0].id;
        }
      });
    }
  },
  methods: {
    async fetchContacts(page = DEFAULT_PAGE, options = {}) {
      const { restoreFocus = false } = options;
      if (!this.showContactSelector) return;

      const value = this.contactSearchQuery.trim();
      if (!value) {
        this.localContacts = [];
        if (restoreFocus) {
          this.$nextTick(() => this.$refs.contactSearchInput?.focus());
        }
        return;
      }

      this.isSearchingContacts = true;
      this.contactSearchError = '';
      try {
        const searchValue = value.charAt(0) === '+' ? value.substring(1) : value;
        const sortAttr = '-last_activity_at';
        const response = await ContactAPI.search(
          encodeURIComponent(searchValue),
          page,
          sortAttr
        );
        this.localContacts = response.data.payload || [];
      } catch (error) {
        this.contactSearchError = this.$t('ACTIVITIES.FORM.CONTACT_SEARCH_ERROR');
        this.localContacts = [];
      } finally {
        this.isSearchingContacts = false;
        if (restoreFocus) {
          this.$nextTick(() => this.$refs.contactSearchInput?.focus());
        }
      }
    },
    onContactSearchInput: debounce(function () {
      this.fetchContacts(DEFAULT_PAGE, { restoreFocus: true });
    }, 300),
    selectContact(contact) {
      this.selectedContact = contact;
      this.contactSearchQuery = '';
    },
    clearSelectedContact() {
      this.selectedContact = null;
      this.localContacts = [];
      this.$nextTick(() => this.$refs.contactSearchInput?.focus());
    },
    handleSubmit() {
      if (this.showContactSelector && !this.effectiveContactId) {
        this.contactSearchError = this.$t('ACTIVITIES.FORM.CONTACT_REQUIRED');
        return;
      }
      this.contactSearchError = '';
      if (this.form.activity_type === 'scheduled_message') {
        const content = (this.form.message_content || '').replace(/<[^>]*>/g, '').trim();
        if (!content) {
          this.$store.dispatch('notifications/show', {
            type: 'error',
            message: this.$t('ACTIVITIES.FORM.MESSAGE_REQUIRED'),
          });
          return;
        }
      }

      const params = { ...this.form };
      if (params.scheduled_at) {
        params.scheduled_at = new Date(params.scheduled_at).toISOString();
      }
      if (params.activity_type === 'scheduled_message' && !params.title) {
        params.title = this.$t('ACTIVITIES.FORM.DEFAULT_SCHEDULED_TITLE');
      }
      const { inbox_id, ...activityParams } = params;
      activityParams.contact_id = this.effectiveContactId;
      this.$emit('submit', { activity: activityParams, inbox_id });
    },
  },
};
</script>

<style scoped lang="scss">
.editor-wrap {
  @apply mb-4;
}

.message-editor {
  @apply px-3;

  ::v-deep {
    .ProseMirror-menubar {
      @apply rounded-tl-[4px];
    }
  }
}
</style>
