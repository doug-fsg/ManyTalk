<script>
import { useAlert } from 'dashboard/composables';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';
import whatsappChannel from 'dashboard/api/channel/whatsappChannel';
import {
  setupFacebookSdk,
  initWhatsAppEmbeddedSignup,
  createMessageHandler,
  isValidBusinessData,
} from './utils';

export default {
  components: { InboxReconnectionRequired },
  props: {
    inbox: {
      type: Object,
      required: true,
    },
    whatsappRegistrationIncomplete: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      isRequestingAuthorization: false,
      isLoadingFacebook: true,
    };
  },
  computed: {
    whatsappAppId() {
      return window.chatwootConfig?.whatsappAppId;
    },
    whatsappConfigurationId() {
      return window.chatwootConfig?.whatsappConfigurationId;
    },
  },
  mounted() {
    this.loadFacebookSdk();
  },
  methods: {
    async loadFacebookSdk() {
      try {
        if (!this.whatsappAppId || !this.whatsappConfigurationId) return;
        await setupFacebookSdk(
          this.whatsappAppId,
          window.chatwootConfig?.whatsappApiVersion
        );
      } catch {
        useAlert(this.$t('INBOX.REAUTHORIZE.FACEBOOK_LOAD_ERROR'));
      } finally {
        this.isLoadingFacebook = false;
      }
    },
    async reauthorizeWhatsApp(params) {
      this.isRequestingAuthorization = true;
      try {
        const response = await whatsappChannel.reauthorizeWhatsApp({
          inboxId: this.inbox.id,
          ...params,
        });
        if (response.data?.id || response.data?.success) {
          useAlert(this.$t('INBOX.REAUTHORIZE.SUCCESS'));
          await this.$store.dispatch('inboxes/get');
          this.$emit('reauthorized');
        } else {
          useAlert(response.data.message || this.$t('INBOX.REAUTHORIZE.ERROR'));
        }
      } catch (error) {
        useAlert(error.message || this.$t('INBOX.REAUTHORIZE.ERROR'));
      } finally {
        this.isRequestingAuthorization = false;
      }
    },
    async handleEmbeddedSignupEvents(data, authCode) {
      if (!data || typeof data !== 'object') return;

      if (
        data.event === 'FINISH' ||
        data.event === 'FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING'
      ) {
        const businessData = data.data;
        if (isValidBusinessData(businessData) && businessData.phone_number_id) {
          await this.reauthorizeWhatsApp({
            code: authCode,
            business_id: businessData.business_id,
            waba_id: businessData.waba_id,
            phone_number_id: businessData.phone_number_id,
          });
        } else {
          useAlert(
            this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.INVALID_BUSINESS_DATA')
          );
        }
      } else if (data.event === 'CANCEL') {
        this.isRequestingAuthorization = false;
        useAlert(this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCELLED'));
      } else if (data.event === 'error') {
        this.isRequestingAuthorization = false;
        useAlert(
          data.error_message ||
            this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SIGNUP_ERROR')
        );
      }
    },
    startEmbeddedSignup(authCode) {
      const messageHandler = createMessageHandler(data =>
        this.handleEmbeddedSignupEvents(data, authCode)
      );
      window.addEventListener('message', messageHandler);
    },
    async handleLoginAndReauthorize() {
      if (!this.whatsappAppId || !this.whatsappConfigurationId) {
        throw new Error(this.$t('INBOX.REAUTHORIZE.CONFIGURATION_ERROR'));
      }

      const authCode = await initWhatsAppEmbeddedSignup(this.whatsappConfigurationId);
      const existingConfig = this.inbox.provider_config;

      if (
        existingConfig?.business_account_id &&
        existingConfig?.phone_number_id
      ) {
        await this.reauthorizeWhatsApp({
          code: authCode,
          business_id: existingConfig.business_account_id,
          waba_id: existingConfig.business_account_id,
          phone_number_id: existingConfig.phone_number_id,
        });
      } else {
        this.startEmbeddedSignup(authCode);
      }
    },
    async requestAuthorization() {
      if (this.isLoadingFacebook) {
        useAlert(this.$t('INBOX.REAUTHORIZE.LOADING_FACEBOOK'));
        return;
      }

      this.isRequestingAuthorization = true;
      try {
        await this.handleLoginAndReauthorize();
      } catch (error) {
        if (error.message === 'Login cancelled') {
          useAlert(this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCELLED'));
        } else {
          useAlert(error.message || this.$t('INBOX.REAUTHORIZE.CONFIGURATION_ERROR'));
        }
      } finally {
        if (!window.FB?.getLoginStatus) {
          this.isRequestingAuthorization = false;
        }
      }
    },
  },
};
</script>

<template>
  <InboxReconnectionRequired
    @reauthorize="requestAuthorization"
  />
</template>
