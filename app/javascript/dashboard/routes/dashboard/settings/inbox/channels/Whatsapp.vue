<script>
import PageHeader from '../../SettingsSubPageHeader.vue';
import Twilio from './Twilio.vue';
import ThreeSixtyDialogWhatsapp from './360DialogWhatsapp.vue';
import CloudWhatsapp from './CloudWhatsapp.vue';
import WhatsappWeb from './WhatsappWeb.vue';
import WhatsappEmbeddedSignup from './WhatsappEmbeddedSignup.vue';

export default {
  components: {
    PageHeader,
    Twilio,
    ThreeSixtyDialogWhatsapp,
    CloudWhatsapp,
    WhatsappWeb,
    WhatsappEmbeddedSignup,
  },
  data() {
    return {
      provider: 'whatsapp_web',
      cloudSetupMode: 'embedded', // 'embedded' | 'manual'
    };
  },
  computed: {
    hasWhatsappEmbeddedConfig() {
      return (
        window.chatwootConfig?.whatsappAppId &&
        window.chatwootConfig.whatsappAppId !== 'none' &&
        window.chatwootConfig?.whatsappConfigurationId &&
        window.chatwootConfig.whatsappConfigurationId !== 'none'
      );
    },
    showCloudEmbedded() {
      return (
        this.provider === 'whatsapp_cloud' &&
        this.hasWhatsappEmbeddedConfig &&
        this.cloudSetupMode === 'embedded'
      );
    },
    showCloudManual() {
      return (
        this.provider === 'whatsapp_cloud' &&
        (this.cloudSetupMode === 'manual' || !this.hasWhatsappEmbeddedConfig)
      );
    },
  },
  watch: {
    provider(newVal) {
      if (newVal === 'whatsapp_cloud' && this.hasWhatsappEmbeddedConfig) {
        this.cloudSetupMode = 'embedded';
      }
    },
  },
};
</script>

<template>
  <div
    class="border border-slate-25 dark:border-slate-800/60 bg-white dark:bg-slate-900 h-full p-6 w-full max-w-full md:w-3/4 md:max-w-[75%] flex-shrink-0 flex-grow-0"
  >
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.WHATSAPP.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.WHATSAPP.DESC')"
    />
    <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
      <label>
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.LABEL') }}
        <select v-model="provider">
          <option value="whatsapp_cloud">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_CLOUD') }}
          </option>
          <option value="whatsapp_web">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_WEB') }}
          </option>
          <option value="twilio">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.TWILIO') }}
          </option>
        </select>
      </label>
    </div>

    <template v-if="provider === 'whatsapp_cloud'">
      <WhatsappEmbeddedSignup v-if="showCloudEmbedded" />
      <CloudWhatsapp v-else-if="showCloudManual" />
      <div
        v-if="showCloudEmbedded"
        class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700"
      >
        <button
          type="button"
          class="text-sm text-slate-600 dark:text-slate-400 hover:text-woot-500 dark:hover:text-woot-500"
          @click="cloudSetupMode = 'manual'"
        >
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.OR_MANUAL_SETUP') }}
        </button>
      </div>
      <div
        v-if="showCloudManual && hasWhatsappEmbeddedConfig"
        class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700"
      >
        <button
          type="button"
          class="text-sm text-slate-600 dark:text-slate-400 hover:text-woot-500 dark:hover:text-woot-500"
          @click="cloudSetupMode = 'embedded'"
        >
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.USE_QUICK_CONNECT') }}
        </button>
      </div>
    </template>
    <Twilio v-else-if="provider === 'twilio'" type="whatsapp" />
    <ThreeSixtyDialogWhatsapp v-else-if="provider === '360dialog'" />
    <WhatsappWeb v-else-if="provider === 'whatsapp_web'" />
  </div>
</template>
