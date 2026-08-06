<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import LoadingState from 'dashboard/components/widgets/LoadingState.vue';
import {
  setupFacebookSdk,
  initWhatsAppEmbeddedSignup,
  createMessageHandler,
  isValidBusinessData,
} from './whatsapp/utils';

export default {
  components: {
    LoadingState,
  },
  data() {
    return {
      fbSdkLoaded: false,
      isProcessing: false,
      processingMessage: '',
      authCodeReceived: false,
      authCode: null,
      businessData: null,
      isAuthenticating: false,
      // Prevents double create when Meta sends FINISH + FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING
      signupCompleted: false,
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
    benefits() {
      return [
        {
          key: 'EASY_SETUP',
          text: this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.BENEFITS.EASY_SETUP'),
        },
        {
          key: 'SECURE_AUTH',
          text: this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.BENEFITS.SECURE_AUTH'),
        },
        {
          key: 'AUTO_CONFIG',
          text: this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.BENEFITS.AUTO_CONFIG'),
        },
      ];
    },
    showLoader() {
      return this.isAuthenticating || this.isProcessing;
    },
  },
  mounted() {
    this.setupMessageListener();
  },
  beforeUnmount() {
    this.cleanupMessageListener();
  },
  methods: {
    handleSignupError(data) {
      this.isProcessing = false;
      this.authCodeReceived = false;
      this.isAuthenticating = false;

      const errorMessage =
        data.error ||
        data.message ||
        this.$t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE');
      useAlert(errorMessage);
    },
    handleSignupCancellation() {
      this.isProcessing = false;
      this.authCodeReceived = false;
      this.isAuthenticating = false;
    },
    handleSignupSuccess(inboxData) {
      this.isProcessing = false;
      this.isAuthenticating = false;
      this.signupCompleted = true;
      this.cleanupMessageListener();

      if (inboxData && inboxData.id) {
        useAlert(this.$t('INBOX_MGMT.FINISH.MESSAGE'));
        this.$router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: inboxData.id,
          },
        });
      } else {
        useAlert(this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SUCCESS_FALLBACK'));
        this.$router.replace({
          name: 'settings_inbox_list',
        });
      }
    },
    async completeSignupFlow(businessDataParam) {
      // Re-entry guard: Meta may emit multiple finish events for one session
      if (this.isProcessing || this.signupCompleted) {
        return;
      }

      if (!this.authCodeReceived || !this.authCode) {
        this.handleSignupError({
          error: this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.AUTH_NOT_COMPLETED'),
        });
        return;
      }

      this.isProcessing = true;
      this.processingMessage = this.$t(
        'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.PROCESSING'
      );

      // Consume auth code immediately so a concurrent finish event cannot reuse it
      const authCode = this.authCode;
      this.authCode = null;
      this.authCodeReceived = false;

      try {
        const params = {
          code: authCode,
          business_id: businessDataParam.business_id,
          waba_id: businessDataParam.waba_id,
          phone_number_id: businessDataParam?.phone_number_id || '',
        };

        const responseData = await this.$store.dispatch(
          'inboxes/createWhatsAppEmbeddedSignup',
          params
        );

        this.handleSignupSuccess(responseData);
      } catch (error) {
        const errorMessage =
          parseAPIErrorResponse(error) ||
          this.$t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE');
        this.handleSignupError({ error: errorMessage });
      }
    },
    async handleEmbeddedSignupData(data) {
      if (this.signupCompleted || this.isProcessing) {
        return;
      }

      if (
        data.event === 'FINISH' ||
        data.event === 'FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING'
      ) {
        const businessDataLocal = data.data;

        if (isValidBusinessData(businessDataLocal)) {
          this.businessData = businessDataLocal;
          if (this.authCodeReceived && this.authCode) {
            await this.completeSignupFlow(businessDataLocal);
          } else {
            this.processingMessage = this.$t(
              'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.WAITING_FOR_AUTH'
            );
          }
        } else {
          this.handleSignupError({
            error: this.$t(
              'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.INVALID_BUSINESS_DATA'
            ),
          });
        }
      } else if (data.event === 'CANCEL') {
        this.handleSignupCancellation();
      } else if (data.event === 'error') {
        this.handleSignupError({
          error:
            data.error_message ||
            this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SIGNUP_ERROR'),
          error_id: data.error_id,
          session_id: data.session_id,
        });
      }
    },
    setupMessageListener() {
      const handler = createMessageHandler(this.handleEmbeddedSignupData);
      window.addEventListener('message', handler);
      this._messageHandler = handler;
    },
    cleanupMessageListener() {
      if (this._messageHandler) {
        window.removeEventListener('message', this._messageHandler);
      }
    },
    async launchEmbeddedSignup() {
      try {
        this.isAuthenticating = true;
        this.processingMessage = this.$t(
          'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.AUTH_PROCESSING'
        );

        await setupFacebookSdk(
          window.chatwootConfig?.whatsappAppId,
          window.chatwootConfig?.whatsappApiVersion
        );
        this.fbSdkLoaded = true;

        const code = await initWhatsAppEmbeddedSignup(
          window.chatwootConfig?.whatsappConfigurationId
        );

        this.authCode = code;
        this.authCodeReceived = true;
        this.processingMessage = this.$t(
          'INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.WAITING_FOR_BUSINESS_INFO'
        );

        if (this.businessData) {
          await this.completeSignupFlow(this.businessData);
        }
      } catch (error) {
        if (error.message === 'Login cancelled') {
          this.isProcessing = false;
          this.isAuthenticating = false;
          useAlert(this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCELLED'));
        } else {
          this.handleSignupError({
            error:
              error.message ||
              this.$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SDK_LOAD_ERROR'),
          });
        }
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <div>
      <h2 class="text-lg font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.TITLE') }}
      </h2>
      <p class="mt-2 text-sm text-slate-600 dark:text-slate-400">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.DESC') }}
      </p>
    </div>

    <ul class="list-disc list-inside space-y-2 text-sm text-slate-600 dark:text-slate-400">
      <li v-for="benefit in benefits" :key="benefit.key">
        {{ benefit.text }}
      </li>
    </ul>

    <a
      :href="$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.LEARN_MORE.URL')"
      target="_blank"
      rel="noopener noreferrer"
      class="text-sm text-woot-500 hover:underline"
    >
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.LEARN_MORE.LINK_TEXT') }}
    </a>

    <loading-state v-if="showLoader" :message="processingMessage" />

    <form v-else @submit.prevent="launchEmbeddedSignup" class="flex justify-start">
      <woot-submit-button
        :loading="uiFlags.isCreating"
        :button-text="$t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SUBMIT_BUTTON')"
      />
    </form>
  </div>
</template>
