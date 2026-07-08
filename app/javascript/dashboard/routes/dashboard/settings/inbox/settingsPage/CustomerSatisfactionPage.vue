<script>
import { useAlert } from 'dashboard/composables';
import SettingsSection from '../../../../../components/SettingsSection.vue';
import InboxesAPI from 'dashboard/api/inboxes';

export default {
  components: { SettingsSection },
  props: {
    inbox: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      csatSurveyEnabled: false,
      message: '',
      buttonText: '',
      language: 'pt_BR',
      templateStatus: null,
      isLoadingTemplate: false,
      isSaving: false,
    };
  },
  computed: {
    isWhatsAppCloud() {
      return (
        this.inbox.channel_type === 'Channel::Whatsapp' &&
        this.inbox.provider === 'whatsapp_cloud'
      );
    },
    templateStatusLabel() {
      if (!this.templateStatus) return '';
      if (this.templateStatus.error === 'TEMPLATE_NOT_FOUND') {
        return this.$t('INBOX_MGMT.CSAT.TEMPLATE_STATUS.NOT_FOUND');
      }
      if (!this.templateStatus.template_exists) {
        return this.$t('INBOX_MGMT.CSAT.TEMPLATE_STATUS.DEFAULT');
      }
      const status = this.templateStatus.status?.toUpperCase();
      return this.$t(`INBOX_MGMT.CSAT.TEMPLATE_STATUS.${status}`, status);
    },
  },
  watch: {
    inbox: {
      handler() {
        this.loadState();
      },
      immediate: true,
    },
  },
  mounted() {
    if (this.isWhatsAppCloud) this.fetchTemplateStatus();
  },
  methods: {
    loadState() {
      const config = this.inbox.csat_config || {};
      this.csatSurveyEnabled = this.inbox.csat_survey_enabled || false;
      this.message = config.message || '';
      this.buttonText =
        config.button_text || this.$t('INBOX_MGMT.CSAT.BUTTON_TEXT.DEFAULT');
      this.language = config.language || 'pt_BR';
    },
    async fetchTemplateStatus() {
      this.isLoadingTemplate = true;
      try {
        const { data } = await InboxesAPI.getCSATTemplateStatus(this.inbox.id);
        if (!data.template_exists && data.error === 'Template not found') {
          this.templateStatus = { template_exists: false, error: 'TEMPLATE_NOT_FOUND' };
        } else {
          this.templateStatus = data;
        }
      } catch {
        this.templateStatus = { template_exists: false, error: 'API_ERROR' };
      } finally {
        this.isLoadingTemplate = false;
      }
    },
    async createTemplate() {
      await InboxesAPI.createCSATTemplate(this.inbox.id, {
        message: this.message,
        button_text: this.buttonText,
        language: this.language,
      });
      useAlert(this.$t('INBOX_MGMT.CSAT.TEMPLATE_CREATION.SUCCESS_MESSAGE'));
      await this.fetchTemplateStatus();
    },
    async saveSettings() {
      this.isSaving = true;
      try {
        const shouldCreateTemplate =
          this.isWhatsAppCloud &&
          this.csatSurveyEnabled &&
          this.message.trim() &&
          !this.templateStatus?.template_exists;

        if (shouldCreateTemplate) {
          await this.createTemplate();
        }

        await this.$store.dispatch('inboxes/updateInbox', {
          id: this.inbox.id,
          formData: false,
          csat_survey_enabled: this.csatSurveyEnabled,
          csat_config: {
            display_type: 'emoji',
            message: this.message,
            button_text: this.buttonText,
            language: this.language,
            survey_rules: {
              operator: 'contains',
              values: [],
            },
          },
        });

        useAlert(this.$t('INBOX_MGMT.CSAT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        const message =
          error?.response?.data?.error ||
          this.$t('INBOX_MGMT.CSAT.API.ERROR_MESSAGE');
        useAlert(message);
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <SettingsSection
      :title="$t('INBOX_MGMT.CSAT.TITLE')"
      :sub-title="$t('INBOX_MGMT.CSAT.SUBTITLE')"
    >
      <label class="csat-field">
        {{ $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CSAT') }}
        <select v-model="csatSurveyEnabled">
          <option :value="true">
            {{ $t('INBOX_MGMT.EDIT.ENABLE_CSAT.ENABLED') }}
          </option>
          <option :value="false">
            {{ $t('INBOX_MGMT.EDIT.ENABLE_CSAT.DISABLED') }}
          </option>
        </select>
      </label>

      <label class="csat-field">
        {{ $t('INBOX_MGMT.CSAT.MESSAGE.LABEL') }}
        <textarea v-model.trim="message" rows="3" class="csat-textarea" />
      </label>

      <label class="csat-field">
        {{ $t('INBOX_MGMT.CSAT.BUTTON_TEXT.LABEL') }}
        <woot-input v-model="buttonText" />
      </label>

      <label class="csat-field">
        {{ $t('INBOX_MGMT.CSAT.LANGUAGE.LABEL') }}
        <select v-model="language">
          <option value="pt_BR">Português (BR)</option>
          <option value="en">English</option>
          <option value="es">Español</option>
        </select>
      </label>

      <p v-if="isWhatsAppCloud" class="csat-note">
        {{ $t('INBOX_MGMT.CSAT.WHATSAPP_NOTE') }}
      </p>

      <p v-if="isWhatsAppCloud && templateStatusLabel" class="csat-status">
        {{ $t('INBOX_MGMT.CSAT.TEMPLATE_STATUS.LABEL') }}: {{ templateStatusLabel }}
      </p>

      <woot-button :is-loading="isSaving" :disabled="isSaving" @click="saveSettings">
        {{ $t('INBOX_MGMT.CSAT.SAVE_BUTTON') }}
      </woot-button>
    </SettingsSection>
  </div>
</template>

<style scoped lang="scss">
.csat-field {
  @apply block w-full max-w-xl mb-4 text-sm text-slate-700 dark:text-slate-200;
}

.csat-textarea {
  @apply w-full mt-1 p-2 rounded-md border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900;
}

.csat-note {
  @apply text-sm text-slate-500 dark:text-slate-400 mb-3;
}

.csat-status {
  @apply text-sm text-slate-700 dark:text-slate-200 mb-3;
}
</style>
