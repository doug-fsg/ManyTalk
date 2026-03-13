<script>
import { mapGetters } from 'vuex';
import EmptyState from '../../../../components/widgets/EmptyState.vue';
import InboxesAPI from 'dashboard/api/inboxes';
import { useAlert } from 'dashboard/composables';

export default {
  components: {
    EmptyState,
  },
  data() {
    return {
      showQrSection: false,
      qrcodeImage: null,
      timeLeft: 20,
      timer: null,
      isGeneratingQr: false,
      isVerifyingConnection: false,
      connectionStatus: null, // 'success' | 'error' | null
      verifyErrorMessage: null,
      connectedPhoneNumber: null,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      accountId: 'getCurrentAccountId',
      account: 'getCurrentAccount',
    }),
    currentInbox() {
      return this.$store.getters['inboxes/getInbox'](
        this.$route.params.inbox_id
      );
    },
    isATwilioInbox() {
      return this.currentInbox.channel_type === 'Channel::TwilioSms';
    },
    isAEmailInbox() {
      return this.currentInbox.channel_type === 'Channel::Email';
    },
    isALineInbox() {
      return this.currentInbox.channel_type === 'Channel::Line';
    },
    isASmsInbox() {
      return this.currentInbox.channel_type === 'Channel::Sms';
    },
    isWhatsAppCloudInbox() {
      return (
        this.currentInbox.channel_type === 'Channel::Whatsapp' &&
        this.currentInbox.provider === 'whatsapp_cloud'
      );
    },
    isWhatsAppWebInbox() {
      return (
        this.currentInbox.channel_type === 'Channel::Api' &&
        this.currentInbox.additional_attributes?.source === 'whatsapp_web'
      );
    },
    message() {
      if (this.isATwilioInbox) {
        return `${this.$t('INBOX_MGMT.FINISH.MESSAGE')}. ${this.$t(
          'INBOX_MGMT.ADD.TWILIO.API_CALLBACK.SUBTITLE'
        )}`;
      }

      if (this.isASmsInbox) {
        return `${this.$t('INBOX_MGMT.FINISH.MESSAGE')}. ${this.$t(
          'INBOX_MGMT.ADD.SMS.BANDWIDTH.API_CALLBACK.SUBTITLE'
        )}`;
      }

      if (this.isALineInbox) {
        return `${this.$t('INBOX_MGMT.FINISH.MESSAGE')}. ${this.$t(
          'INBOX_MGMT.ADD.LINE_CHANNEL.API_CALLBACK.SUBTITLE'
        )}`;
      }

      if (this.isWhatsAppCloudInbox) {
        return `${this.$t('INBOX_MGMT.FINISH.MESSAGE')}. ${this.$t(
          'INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.SUBTITLE'
        )}`;
      }

      if (this.isAEmailInbox && !this.currentInbox.provider) {
        return this.$t('INBOX_MGMT.ADD.EMAIL_CHANNEL.FINISH_MESSAGE');
      }

      if (this.currentInbox.web_widget_script) {
        return this.$t('INBOX_MGMT.FINISH.WEBSITE_SUCCESS');
      }

      return this.$t('INBOX_MGMT.FINISH.MESSAGE');
    },
  },
  beforeUnmount() {
    if (this.timer) clearInterval(this.timer);
  },
  methods: {
    async generateQrCode() {
      if (!this.currentInbox?.id || this.isGeneratingQr) return;
      this.connectionStatus = null;
      this.verifyErrorMessage = null;
      this.showQrSection = true;
      this.isGeneratingQr = true;

      try {
        const payload = {
          event: 'qrcode_created',
          currentUser: this.currentUser,
          accountId: this.accountId,
          account: this.account,
          inbox: this.currentInbox,
          enableGroup: false,
          enableAgentName: false,
          timestamp: new Date().toISOString(),
        };

        const response = await InboxesAPI.postWhatsappWebConnection(
          this.currentInbox.id,
          payload,
          'arraybuffer'
        );

        const bytes = new Uint8Array(response.data);
        let binary = '';
        const chunkSize = 8192;
        for (let i = 0; i < bytes.length; i += chunkSize) {
          binary += String.fromCharCode.apply(
            null,
            bytes.subarray(i, i + chunkSize)
          );
        }
        this.qrcodeImage = `data:image/png;base64,${btoa(binary)}`;
        this.startQrTimer();
      } catch (error) {
        if (error.response?.status === 503) {
          useAlert(this.$t('INBOX_MGMT.FINISH.WHATSAPP_WEB.DISCONNECTED'));
        } else {
          useAlert(
            error.response?.data?.message ||
              this.$t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE')
          );
        }
        this.showQrSection = false;
      } finally {
        this.isGeneratingQr = false;
      }
    },

    startQrTimer() {
      this.connectionStatus = null;
      this.verifyErrorMessage = null;
      this.timeLeft = 20;
      this.timer = setInterval(async () => {
        if (this.timeLeft > 0) {
          this.timeLeft -= 1;
        } else {
          clearInterval(this.timer);
          this.timer = null;
          this.qrcodeImage = null;
          this.isVerifyingConnection = true;
          this.showQrSection = true;

          try {
            const response = await InboxesAPI.postWhatsappWebConnection(
              this.currentInbox.id,
              {
                event: 'verify_connection',
                currentUser: this.currentUser,
                accountId: this.accountId,
                account: this.account,
                inbox: this.currentInbox,
                timestamp: new Date().toISOString(),
              },
              'json'
            );
            this.connectionStatus = 'success';
            this.connectedPhoneNumber = this.parsePhoneFromWid(response.data);
          } catch (error) {
            this.connectionStatus = 'error';
            if (error.response?.status === 503) {
              this.verifyErrorMessage = this.$t(
                'INBOX_MGMT.FINISH.WHATSAPP_WEB.DISCONNECTED'
              );
            } else {
              this.verifyErrorMessage =
                error.response?.data?.message ||
                this.$t('INBOX_MGMT.FINISH.WHATSAPP_WEB.VERIFY_ERROR');
            }
            useAlert(this.verifyErrorMessage);
          } finally {
            this.isVerifyingConnection = false;
          }
        }
      }, 1000);
    },

    parsePhoneFromWid(data) {
      if (!data) return null;
      const item = Array.isArray(data) ? data[0] : data;
      const wid = item?.wid;
      if (!wid || typeof wid !== 'string') return null;
      const match = wid.match(/^(\d+)/);
      return match ? match[1] : null;
    },

    resetQrState() {
      this.connectionStatus = null;
      this.verifyErrorMessage = null;
      this.connectedPhoneNumber = null;
      this.showQrSection = false;
      this.qrcodeImage = null;
      if (this.timer) {
        clearInterval(this.timer);
        this.timer = null;
      }
      this.timeLeft = 20;
    },

    async generateNewQrCode() {
      this.resetQrState();
      await this.$nextTick();
      this.generateQrCode();
    },
  },
};
</script>

<template>
  <div
    class="border border-slate-25 dark:border-slate-800/60 bg-white dark:bg-slate-900 h-full p-6 w-full max-w-full md:w-3/4 md:max-w-[75%] flex-shrink-0 flex-grow-0"
  >
    <EmptyState
      :title="$t('INBOX_MGMT.FINISH.TITLE')"
      :message="message"
      :button-text="$t('INBOX_MGMT.FINISH.BUTTON_TEXT')"
    >
      <div class="w-full text-center">
        <div class="my-4 mx-auto max-w-[70%]">
          <woot-code
            v-if="currentInbox.web_widget_script"
            :script="currentInbox.web_widget_script"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isATwilioInbox"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div v-if="isWhatsAppCloudInbox" class="w-[50%] max-w-[50%] ml-[25%]">
          <p class="mt-8 font-medium text-slate-700 dark:text-slate-200">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.WEBHOOK_URL') }}
          </p>
          <woot-code lang="html" :script="currentInbox.callback_webhook_url" />
          <p class="mt-8 font-medium text-slate-700 dark:text-slate-200">
            {{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.WEBHOOK_VERIFICATION_TOKEN'
              )
            }}
          </p>
          <woot-code
            lang="html"
            :script="currentInbox.provider_config.webhook_verify_token"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isALineInbox"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isASmsInbox"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div
          v-if="isAEmailInbox && !currentInbox.provider"
          class="w-[50%] max-w-[50%] ml-[25%]"
        >
          <woot-code lang="html" :script="currentInbox.forward_to_email" />
        </div>
        <div v-if="isWhatsAppWebInbox && showQrSection" class="mt-6 text-left max-w-[600px] mx-auto">
          <woot-loading-state
            v-if="isGeneratingQr"
            :message="$t('INBOX_MGMT.FINISH.WHATSAPP_WEB.GENERATING_QR')"
          />
          <woot-loading-state
            v-else-if="isVerifyingConnection"
            :message="$t('INBOX_MGMT.FINISH.WHATSAPP_WEB.VERIFYING')"
          />
          <div v-else-if="connectionStatus === 'success'" class="py-4">
            <div
              class="flex items-center gap-3 p-4 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800"
            >
              <fluent-icon
                icon="checkmark-circle"
                class="flex-shrink-0 w-10 h-10 text-green-600 dark:text-green-400"
              />
              <div class="min-w-0 flex-1">
                <p class="font-medium text-green-800 dark:text-green-200">
                  {{ $t('INBOX_MGMT.FINISH.WHATSAPP_WEB.CONNECTED_SUCCESS') }}
                </p>
                <p class="text-sm text-green-700 dark:text-green-300">
                  {{ $t('INBOX_MGMT.FINISH.WHATSAPP_WEB.CONNECTED_DESC') }}
                </p>
                <p
                  v-if="connectedPhoneNumber"
                  class="mt-1 text-xs text-slate-500 dark:text-slate-400"
                >
                  {{ $t('INBOX_MGMT.FINISH.WHATSAPP_WEB.CONNECTED_PHONE') }}:
                  <span class="font-mono">{{ connectedPhoneNumber }}</span>
                </p>
              </div>
            </div>
          </div>
          <div v-else-if="connectionStatus === 'error'" class="py-4">
            <div
              class="flex items-center gap-3 p-4 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800"
            >
              <fluent-icon
                icon="dismiss-circle"
                class="flex-shrink-0 w-10 h-10 text-red-600 dark:text-red-400"
              />
              <div>
                <p class="font-medium text-red-800 dark:text-red-200">
                  {{ $t('INBOX_MGMT.FINISH.WHATSAPP_WEB.VERIFY_FAILED') }}
                </p>
                <p class="text-sm text-red-700 dark:text-red-300">
                  {{ verifyErrorMessage }}
                </p>
              </div>
            </div>
          </div>
          <div v-else-if="qrcodeImage" class="flex gap-4 items-start">
            <img :src="qrcodeImage" alt="QR Code" class="max-w-[200px] max-h-[200px]" />
            <div>
              <p class="text-sm text-slate-600 dark:text-slate-400">
                {{ $t('INBOX_MGMT.FINISH.WHATSAPP_WEB.QR_EXPIRY') }}
              </p>
              <p class="mt-2 font-medium">{{ timeLeft }} {{ $t('INBOX_MGMT.FINISH.WHATSAPP_WEB.SECONDS_LEFT') }}</p>
            </div>
          </div>
        </div>
        <div class="flex justify-center gap-2 mt-4 flex-wrap">
          <template v-if="isWhatsAppWebInbox">
            <woot-submit-button
              v-if="connectionStatus !== 'success' && !isVerifyingConnection && (!showQrSection || !qrcodeImage || connectionStatus === 'error')"
              :loading="isGeneratingQr"
              :button-text="connectionStatus === 'error' ? $t('INBOX_MGMT.FINISH.WHATSAPP_WEB.GENERATE_NEW_QR') : $t('INBOX_MGMT.FINISH.READ_QRCODE')"
              button-class="rounded bg-green-600 hover:bg-green-700 text-white font-medium px-4 py-2"
              @click="connectionStatus === 'error' ? generateNewQrCode() : generateQrCode()"
            />
            <template v-if="connectionStatus === 'success'">
              <router-link
                class="rounded bg-green-600 hover:bg-green-700 text-white font-medium px-4 py-2 inline-flex items-center gap-2 transition-colors"
                :to="{
                  name: 'inbox_dashboard',
                  params: { inboxId: $route.params.inbox_id },
                }"
              >
                {{ $t('INBOX_MGMT.FINISH.BUTTON_TEXT') }}
              </router-link>
              <router-link
                class="rounded border border-slate-300 dark:border-slate-600 bg-transparent hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300 font-medium px-4 py-2 inline-flex items-center gap-2 transition-colors"
                :to="{
                  name: 'settings_inbox_show',
                  params: { inboxId: $route.params.inbox_id },
                }"
              >
                {{ $t('INBOX_MGMT.FINISH.WHATSAPP_WEB.ADVANCED_SETTINGS') }}
              </router-link>
            </template>
            <router-link
              v-if="connectionStatus !== 'success'"
              class="rounded border border-slate-300 dark:border-slate-600 bg-transparent hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300 font-medium px-4 py-2 inline-flex items-center transition-colors"
              :to="{
                name: 'inbox_dashboard',
                params: { inboxId: $route.params.inbox_id },
              }"
            >
              {{ $t('INBOX_MGMT.FINISH.DO_THIS_LATER') }}
            </router-link>
          </template>
          <template v-else>
            <router-link
              class="rounded button hollow primary"
              :to="{
                name: 'settings_inbox_show',
                params: { inboxId: $route.params.inbox_id },
              }"
            >
              {{ $t('INBOX_MGMT.FINISH.MORE_SETTINGS') }}
            </router-link>
            <router-link
              class="rounded button success"
              :to="{
                name: 'inbox_dashboard',
                params: { inboxId: $route.params.inbox_id },
              }"
            >
              {{ $t('INBOX_MGMT.FINISH.BUTTON_TEXT') }}
            </router-link>
          </template>
        </div>
      </div>
    </EmptyState>
  </div>
</template>
