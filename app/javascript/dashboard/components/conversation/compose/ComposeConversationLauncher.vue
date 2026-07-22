<template>
  <woot-modal :show.sync="localShow" :on-close="onClose">
    <div class="h-auto overflow-auto flex flex-col">
      <template v-if="showFullContactForm">
        <woot-modal-header
          :header-title="$t('CREATE_CONTACT.TITLE')"
          :header-content="$t('CREATE_CONTACT.DESC')"
        />
        <contact-form
          :in-progress="uiFlags.isCreating"
          :on-submit="onFullContactCreate"
          @cancel="closeFullContactForm"
        />
      </template>

      <template v-else>
        <woot-modal-header
          :header-title="$t('COMPOSE_CONVERSATION.TITLE')"
          :header-content="$t('COMPOSE_CONVERSATION.DESC')"
        />

        <quick-contact-input
          ref="quickContactInput"
          :selected-contact="selectedContact"
          :is-creating-contact="isCreatingContact"
          @select="onContactSelect"
          @clear="clearSelectedContact"
          @create-quick="onQuickCreate"
        />

        <conversation-form
          v-if="selectedContact && !isCreatingContact"
          :key="selectedContact.id"
          :contact="conversationContact"
          :on-submit="onSubmitConversation"
          :auto-select-single-inbox="true"
          :hide-contact-field="true"
          :submit-button-label="$t('COMPOSE_CONVERSATION.START_BUTTON')"
          @success="onConversationSuccess"
          @cancel="onClose"
        />

        <div
          v-if="!selectedContact"
          class="px-8 pb-6 pt-1 border-t border-slate-100 dark:border-slate-800"
        >
          <button
            type="button"
            class="text-xs font-medium text-slate-600 dark:text-slate-300 hover:text-woot-600 dark:hover:text-woot-400 hover:underline underline-offset-2 cursor-pointer transition-colors duration-200"
            @click="showFullContactForm = true"
          >
            {{ $t('COMPOSE_CONVERSATION.FULL_CONTACT_LINK') }}
          </button>
        </div>
      </template>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { ExceptionWithMessage } from 'shared/helpers/CustomErrors';
import QuickContactInput from './QuickContactInput.vue';
import ConversationForm from 'dashboard/routes/dashboard/conversation/contact/ConversationForm.vue';
import ContactForm from 'dashboard/routes/dashboard/conversation/contact/ContactForm.vue';
import { buildQuickContactPayload } from './helpers/composeConversationHelper';

export default {
  name: 'ComposeConversationLauncher',
  components: {
    QuickContactInput,
    ConversationForm,
    ContactForm,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedContact: null,
      isCreatingContact: false,
      showFullContactForm: false,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
      getContact: 'contacts/getContact',
    }),
    conversationContact() {
      if (!this.selectedContact?.id) {
        return {};
      }

      return {
        ...this.selectedContact,
        ...this.getContact(this.selectedContact.id),
      };
    },
    localShow: {
      get() {
        return this.show;
      },
      set(value) {
        this.$emit('update:show', value);
      },
    },
  },
  watch: {
    show(isOpen) {
      if (isOpen) {
        this.resetState();
      }
    },
  },
  methods: {
    resetState() {
      this.selectedContact = null;
      this.isCreatingContact = false;
      this.showFullContactForm = false;
      this.$nextTick(() => {
        this.$refs.quickContactInput?.resetState();
      });
    },
    onClose() {
      this.localShow = false;
      this.$emit('close');
    },
    closeFullContactForm() {
      this.showFullContactForm = false;
    },
    clearSelectedContact() {
      this.selectedContact = null;
      this.$nextTick(() => {
        this.$refs.quickContactInput?.focusInput();
      });
    },
    async onContactSelect(contact) {
      this.selectedContact = contact;
      await this.$store.dispatch('contacts/fetchContactableInbox', contact.id);
    },
    async onQuickCreate(query) {
      const payload = buildQuickContactPayload(query);
      if (!payload) {
        return;
      }

      this.isCreatingContact = true;

      try {
        const contact = await this.$store.dispatch('contacts/create', payload);
        this.selectedContact = contact;
        await this.$store.dispatch('contacts/fetchContactableInbox', contact.id);
        this.$refs.quickContactInput?.resetState();
      } catch (error) {
        if (error instanceof ExceptionWithMessage) {
          useAlert(error.data);
        } else {
          useAlert(this.$t('COMPOSE_CONVERSATION.CREATE_ERROR'));
        }
      } finally {
        this.isCreatingContact = false;
      }
    },
    async onFullContactCreate(contactItem) {
      try {
        const contact = await this.$store.dispatch('contacts/create', contactItem);
        this.showFullContactForm = false;
        await this.onContactSelect(contact);
      } catch (_error) {
        // ContactForm handles validation errors
      }
    },
    async onSubmitConversation(params, isFromWhatsApp) {
      return this.$store.dispatch('contactConversations/create', {
        params,
        isFromWhatsApp,
      });
    },
    onConversationSuccess() {
      this.onClose();
    },
  },
};
</script>
