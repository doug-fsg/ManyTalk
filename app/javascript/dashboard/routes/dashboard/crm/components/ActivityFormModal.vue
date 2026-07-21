<template>
  <div class="h-auto overflow-auto flex flex-col">
    <woot-modal-header
      :header-title="$t(activity ? 'ACTIVITIES.EDIT' : 'ACTIVITIES.CREATE')"
    />
    <div
      v-if="!activity && form.activity_type === 'scheduled_message'"
      class="px-6 pt-2 pb-0 flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400"
    >
      <span
        :class="[
          'px-2 py-1 rounded-full font-medium',
          currentStep === 1 ? 'bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-300' : 'bg-slate-100 dark:bg-slate-700'
        ]"
      >
        1. {{ $t('ACTIVITIES.FORM.STEP_WHEN') }}
      </span>
      <span
        :class="[
          'px-2 py-1 rounded-full font-medium',
          currentStep === 2 ? 'bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-300' : 'bg-slate-100 dark:bg-slate-700'
        ]"
      >
        2. {{ $t('ACTIVITIES.FORM.STEP_CHANNEL') }}
      </span>
    </div>
    <form class="flex flex-col w-full space-y-4" @submit.prevent="handleSubmit">
      <div class="w-full space-y-4">
        <div
          v-if="pipelineContextLabel"
          class="px-3 py-2 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-xs text-slate-600 dark:text-slate-300"
        >
          {{ pipelineContextLabel }}
        </div>

        <template v-if="currentStep === 1">
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
            <woot-button variant="clear" size="tiny" icon="edit" @click="clearSelectedContact" />
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

        <label>
          {{ $t('ACTIVITIES.FORM.TYPE_LABEL') }}
          <select v-model="form.activity_type" class="mt-2">
            <option value="task">{{ $t('ACTIVITIES.TYPE.TASK') }}</option>
            <option value="scheduled_message">{{ $t('ACTIVITIES.TYPE.SCHEDULED_MESSAGE') }}</option>
          </select>
        </label>

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
            <textarea v-model="form.description" rows="2" class="mt-2" />
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">{{ $t('ACTIVITIES.FORM.DESCRIPTION_HINT') }}</p>
          </label>
        </template>

        <div>
          <label>
            {{ $t('ACTIVITIES.FORM.SCHEDULED_AT') }}
            <input v-model="form.scheduled_at" type="datetime-local" required class="mt-2" />
          </label>
          <div v-if="!activity" class="mt-3 flex flex-wrap gap-2">
            <button
              v-for="shortcut in scheduleShortcuts"
              :key="shortcut.id"
              type="button"
              class="px-2.5 py-1.5 text-xs rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
              @click="applyScheduleShortcut(shortcut.id)"
            >
              {{ shortcut.label }}
            </button>
          </div>
          <div v-if="formattedScheduledDate" class="mt-2 px-3 py-2 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
            <p class="text-xs text-blue-700 dark:text-blue-300 flex items-center gap-1">
              <fluent-icon icon="info" size="12" />
              {{ formattedScheduledDate }}
            </p>
          </div>
        </div>
        </template>

        <template v-if="currentStep === 2 || (isEditing && showMessageFields)">
        <div v-if="showMessageFields" class="space-y-4">
          <label>
            {{ $t('ACTIVITIES.FORM.INBOX') }}
            <select v-model="form.inbox_id" required class="mt-2" @change="onInboxChange">
              <option value="">{{ $t('ACTIVITIES.FORM.SELECT_INBOX') }}</option>
              <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
                {{ inbox.name }} ({{ inboxChannelLabel(inbox) }})
              </option>
            </select>
          </label>

          <div v-if="isWhatsappInbox" class="px-3 py-2 bg-amber-50 dark:bg-amber-900/20 rounded-lg border border-amber-200 dark:border-amber-800">
            <p class="text-xs text-amber-800 dark:text-amber-200">
              {{ $t('ACTIVITIES.FORM.WHATSAPP_WINDOW_HINT') }}
            </p>
          </div>

          <div v-if="!isWhatsappInbox || whatsappSendMode !== 'template_only'" class="editor-wrap">
            <label>{{ $t('ACTIVITIES.FORM.MESSAGE_CONTENT') }}</label>
            <div class="mt-2">
              <woot-message-editor
                v-model="form.message_content"
                class="message-editor"
                :placeholder="$t('ACTIVITIES.FORM.MESSAGE_PLACEHOLDER')"
              />
            </div>
          </div>

          <div v-if="isWhatsappInbox" class="space-y-2">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
              {{ $t('ACTIVITIES.FORM.WHATSAPP_TEMPLATE_FALLBACK') }} *
            </label>
            <whatsapp-templates
              v-if="form.inbox_id"
              :inbox-id="Number(form.inbox_id)"
              :variables="messageVariables"
              @on-send="onWhatsappTemplateSelected"
              @pickTemplate="onWhatsappTemplatePick"
            />
            <p v-if="whatsappTemplateParams" class="text-xs text-green-600 dark:text-green-400">
              {{ $t('ACTIVITIES.FORM.WHATSAPP_TEMPLATE_SELECTED', { name: whatsappTemplateParams.name }) }}
            </p>
          </div>

          <p class="text-[11px] text-slate-500 dark:text-slate-400">
            {{ isWhatsappInbox ? $t('ACTIVITIES.FORM.WHATSAPP_SCHEDULED_FOOTER') : $t('ACTIVITIES.FORM.SCHEDULED_MESSAGE_FOOTER') }}
          </p>
        </div>
        </template>
      </div>

      <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
        <woot-button
          v-if="showBackButton"
          variant="clear"
          @click.prevent="goToPreviousStep"
        >
          {{ $t('ACTIVITIES.FORM.BACK') }}
        </woot-button>
        <woot-button
          v-if="showNextButton"
          color-scheme="primary"
          @click.prevent="goToNextStep"
        >
          {{ $t('ACTIVITIES.FORM.NEXT') }}
        </woot-button>
        <woot-button v-if="showSubmitButton" type="submit" color-scheme="primary">
          {{ activity ? $t('ACTIVITIES.FORM.SUBMIT_UPDATE') : $t('ACTIVITIES.FORM.SUBMIT') }}
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
import WhatsappTemplates from 'dashboard/routes/dashboard/conversation/contact/WhatsappTemplates.vue';
import ContactAPI from 'dashboard/api/contacts';
import { INBOX_TYPES } from 'shared/mixins/inboxMixin';
import { getMessageVariables } from '@chatwoot/utils';
import { mapGetters } from 'vuex';
import debounce from 'lodash/debounce';
import { getStage } from '../utils/pipelinePositionsHelper';

const DEFAULT_PAGE = 1;
const SCHEDULABLE_CHANNELS = [
  INBOX_TYPES.WHATSAPP,
  INBOX_TYPES.SMS,
  INBOX_TYPES.API,
  INBOX_TYPES.TWILIO,
];

export default {
  components: {
    FluentIcon,
    WootMessageEditor,
    WootThumbnail,
    WhatsappTemplates,
  },
  props: {
    activity: { type: Object, default: null },
    contactId: { type: Number, default: null },
    pipelineId: { type: [Number, String], default: null },
    contact: { type: Object, default: null },
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    showContactSelector() {
      return this.contactId == null;
    },
    effectiveContactId() {
      if (this.contactId != null) return this.contactId;
      return this.selectedContact?.id ?? null;
    },
    effectiveContact() {
      if (this.selectedContact) return this.selectedContact;
      return { id: this.contactId };
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
      const all = this.$store.getters['inboxes/getInboxes'] || [];
      return all.filter(inbox => {
        if (!SCHEDULABLE_CHANNELS.includes(inbox.channel_type)) return false;
        if (inbox.channel_type === INBOX_TYPES.TWILIO && inbox.medium !== 'sms') return false;
        return true;
      });
    },
    selectedInbox() {
      return this.inboxes.find(i => String(i.id) === String(this.form.inbox_id));
    },
    isWhatsappInbox() {
      return this.selectedInbox?.channel_type === INBOX_TYPES.WHATSAPP;
    },
    whatsappSendMode() {
      return this.metadata?.whatsapp?.send_mode || 'session_with_template_fallback';
    },
    messageVariables() {
      return getMessageVariables({
        conversation: {
          meta: { sender: this.effectiveContact, assignee: this.currentUser },
          id: '',
          custom_attributes: {},
        },
        contact: this.effectiveContact,
      });
    },
    formattedScheduledDate() {
      if (!this.form.scheduled_at) return '';
      const date = new Date(this.form.scheduled_at);
      const now = new Date();
      const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const targetDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
      const daysDiff = Math.floor((targetDate - nowDate) / (1000 * 60 * 60 * 24));
      const timeString = date.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
      if (daysDiff === 0) return this.$t('ACTIVITIES.FORM.SCHEDULED_TODAY', { time: timeString });
      if (daysDiff === 1) return this.$t('ACTIVITIES.FORM.SCHEDULED_TOMORROW', { time: timeString });
      if (daysDiff === -1) return this.$t('ACTIVITIES.FORM.SCHEDULED_YESTERDAY', { time: timeString });
      if (daysDiff < 0) return this.$t('ACTIVITIES.FORM.SCHEDULED_DAYS_AGO', { days: Math.abs(daysDiff), time: timeString });
      const dateString = date.toLocaleDateString(undefined, { day: '2-digit', month: '2-digit', year: 'numeric' });
      return this.$t('ACTIVITIES.FORM.SCHEDULED_FUTURE', { date: dateString, time: timeString });
    },
    showMessageFields() {
      return this.form.activity_type === 'scheduled_message';
    },
    isEditing() {
      return Boolean(this.activity);
    },
    currentStepFieldsVisible() {
      return this.isEditing || this.currentStep === 1;
    },
    showNextButton() {
      return !this.isEditing
        && this.currentStep === 1
        && this.form.activity_type === 'scheduled_message';
    },
    showBackButton() {
      return !this.isEditing
        && this.currentStep === 2
        && this.form.activity_type === 'scheduled_message';
    },
    showSubmitButton() {
      if (this.isEditing) return true;
      if (this.form.activity_type === 'task') return true;
      return this.currentStep === 2;
    },
    pipelineContextLabel() {
      if (!this.pipelineId || !this.effectiveContactId) return '';
      const contact = this.contact
        || this.$store.getters['contacts/getContact'](this.effectiveContactId);
      const stage = contact ? getStage(contact, this.pipelineId) : null;
      if (stage) {
        return this.$t('ACTIVITIES.FORM.PIPELINE_CONTEXT', { stage });
      }
      return this.$t('ACTIVITIES.FORM.PIPELINE_LINKED');
    },
    scheduleShortcuts() {
      return [
        { id: 'today_17', label: this.$t('ACTIVITIES.FORM.QUICK_TODAY_17') },
        { id: 'tomorrow_10', label: this.$t('ACTIVITIES.FORM.QUICK_TOMORROW_10') },
        { id: 'followup_3d', label: this.$t('ACTIVITIES.FORM.QUICK_FOLLOWUP_3D') },
      ];
    },
  },
  data() {
    return {
      currentStep: 1,
      form: {
        activity_type: 'task',
        title: '',
        description: '',
        scheduled_at: '',
        message_content: '',
        inbox_id: '',
      },
      metadata: {},
      whatsappTemplateParams: null,
      contactSearchQuery: '',
      localContacts: [],
      selectedContact: null,
      isSearchingContacts: false,
      contactSearchError: '',
    };
  },
  watch: {
    'form.activity_type'(newVal) {
      this.currentStep = 1;
      if (newVal === 'task') {
        this.form.inbox_id = '';
        this.whatsappTemplateParams = null;
      } else if (newVal === 'scheduled_message') {
        this.form.title = '';
        this.form.description = '';
      }
    },
  },
  async mounted() {
    await this.$store.dispatch('inboxes/get');
    if (this.activity) {
      this.form = {
        activity_type: this.activity.activity_type,
        title: this.activity.title,
        description: this.activity.description,
        scheduled_at: '',
        message_content: this.activity.message_content || '',
        inbox_id: this.activity.inbox?.id || '',
      };
      if (this.activity.scheduled_at) {
        const date = new Date(this.activity.scheduled_at);
        this.form.scheduled_at = date.toISOString().slice(0, 16);
      }
      this.metadata = this.activity.metadata || {};
      this.whatsappTemplateParams = this.metadata?.whatsapp?.template_params || null;
    } else if (this.inboxes.length === 1) {
      this.form.inbox_id = this.inboxes[0].id;
    }
  },
  methods: {
    toDateTimeLocalValue(date) {
      const offset = date.getTimezoneOffset();
      const local = new Date(date.getTime() - offset * 60 * 1000);
      return local.toISOString().slice(0, 16);
    },
    applyScheduleShortcut(shortcutId) {
      const now = new Date();
      let target = new Date(now);

      if (shortcutId === 'today_17') {
        target.setHours(17, 0, 0, 0);
        if (target <= now) {
          target.setDate(target.getDate() + 1);
        }
      } else if (shortcutId === 'tomorrow_10') {
        target.setDate(target.getDate() + 1);
        target.setHours(10, 0, 0, 0);
      } else if (shortcutId === 'followup_3d') {
        target.setDate(target.getDate() + 3);
        target.setHours(10, 0, 0, 0);
      }

      this.form.scheduled_at = this.toDateTimeLocalValue(target);
    },
    validateStepOne() {
      if (this.showContactSelector && !this.effectiveContactId) {
        this.contactSearchError = this.$t('ACTIVITIES.FORM.CONTACT_REQUIRED');
        return false;
      }
      this.contactSearchError = '';

      if (!this.form.scheduled_at) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: this.$t('ACTIVITIES.FORM.SCHEDULE_REQUIRED'),
        });
        return false;
      }

      if (this.form.activity_type === 'task' && !this.form.title?.trim()) {
        return false;
      }

      return true;
    },
    goToNextStep() {
      if (!this.validateStepOne()) return;
      this.currentStep = 2;
    },
    goToPreviousStep() {
      this.currentStep = 1;
    },
    inboxChannelLabel(inbox) {
      const labels = {
        [INBOX_TYPES.WHATSAPP]: 'WhatsApp',
        [INBOX_TYPES.SMS]: 'SMS',
        [INBOX_TYPES.API]: 'API',
        [INBOX_TYPES.TWILIO]: 'SMS',
      };
      return labels[inbox.channel_type] || inbox.channel_type;
    },
    onInboxChange() {
      this.whatsappTemplateParams = null;
    },
    onWhatsappTemplatePick() {},
    onWhatsappTemplateSelected({ message, templateParams }) {
      this.whatsappTemplateParams = templateParams;
      if (!this.form.message_content?.trim()) {
        this.form.message_content = message;
      }
    },
    async fetchContacts(page = DEFAULT_PAGE, options = {}) {
      const { restoreFocus = false } = options;
      if (!this.showContactSelector) return;
      const value = this.contactSearchQuery.trim();
      if (!value) {
        this.localContacts = [];
        if (restoreFocus) this.$nextTick(() => this.$refs.contactSearchInput?.focus());
        return;
      }
      this.isSearchingContacts = true;
      this.contactSearchError = '';
      try {
        const searchValue = value.charAt(0) === '+' ? value.substring(1) : value;
        const response = await ContactAPI.search(encodeURIComponent(searchValue), page, '-last_activity_at');
        this.localContacts = response.data.payload || [];
      } catch (error) {
        this.contactSearchError = this.$t('ACTIVITIES.FORM.CONTACT_SEARCH_ERROR');
        this.localContacts = [];
      } finally {
        this.isSearchingContacts = false;
        if (restoreFocus) this.$nextTick(() => this.$refs.contactSearchInput?.focus());
      }
    },
    onContactSearchInput: debounce(function onSearch() {
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
      if (this.currentStep === 1 && this.showNextButton) {
        this.goToNextStep();
        return;
      }

      if (!this.validateStepOne()) {
        return;
      }

      if (this.form.activity_type === 'scheduled_message') {
        const content = (this.form.message_content || '').replace(/<[^>]*>/g, '').trim();
        if (this.isWhatsappInbox) {
          if (!this.whatsappTemplateParams) {
            this.$store.dispatch('notifications/show', {
              type: 'error',
              message: this.$t('ACTIVITIES.FORM.WHATSAPP_TEMPLATE_REQUIRED'),
            });
            return;
          }
        } else if (!content) {
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

      const metadata = { ...(this.metadata || {}) };
      if (this.isWhatsappInbox && this.whatsappTemplateParams) {
        metadata.whatsapp = {
          send_mode: 'session_with_template_fallback',
          template_params: this.whatsappTemplateParams,
        };
      }
      params.metadata = metadata;

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
