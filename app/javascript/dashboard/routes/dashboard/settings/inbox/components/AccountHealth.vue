<script>
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import WhatsappPricingSummary from './WhatsappPricingSummary.vue';
import {
  humanizeAccountMode,
  humanizeMessagingLimitTier,
  humanizeNameStatus,
  humanizeQualityRating,
  humanizeVerificationStatus,
} from 'dashboard/helper/whatsappHealthLabels';

const QUALITY_COLORS = {
  GREEN: 'text-green-600 dark:text-green-400',
  YELLOW: 'text-amber-600 dark:text-amber-400',
  RED: 'text-red-600 dark:text-red-400',
};

const STATUS_COLORS = {
  APPROVED: 'text-green-600 dark:text-green-400',
  AVAILABLE_WITHOUT_REVIEW: 'text-green-600 dark:text-green-400',
  PENDING_REVIEW: 'text-amber-600 dark:text-amber-400',
  DECLINED: 'text-red-600 dark:text-red-400',
  EXPIRED: 'text-red-600 dark:text-red-400',
};

const VERIFICATION_COLORS = {
  VERIFIED: 'text-green-600 dark:text-green-400',
  NOT_VERIFIED: 'text-amber-600 dark:text-amber-400',
  EXPIRED: 'text-red-600 dark:text-red-400',
};

const MODE_COLORS = {
  LIVE: 'text-green-600 dark:text-green-400',
  SANDBOX: 'text-amber-600 dark:text-amber-400',
};

export default {
  components: { SettingsSection, WhatsappPricingSummary },
  props: {
    healthData: {
      type: Object,
      default: null,
    },
    pricingData: {
      type: Object,
      default: null,
    },
    isLoadingPricing: {
      type: Boolean,
      default: false,
    },
    pricingError: {
      type: String,
      default: '',
    },
    pricingErrorCode: {
      type: String,
      default: '',
    },
    isRegisteringWebhook: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    healthItems() {
      if (!this.healthData) return [];

      const {
        display_phone_number: displayPhoneNumber,
        verified_name: verifiedName,
        name_status: nameStatus,
        code_verification_status: codeVerificationStatus,
        quality_rating: qualityRating,
        messaging_limit_tier: messagingLimitTier,
        account_mode: accountMode,
      } = this.healthData;

      return [
        {
          key: 'displayPhoneNumber',
          label: this.$t(
            'INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.DISPLAY_PHONE_NUMBER.LABEL'
          ),
          displayValue: displayPhoneNumber || '—',
        },
        {
          key: 'verifiedName',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.VERIFIED_NAME.LABEL'),
          displayValue: verifiedName || '—',
        },
        {
          key: 'displayNameStatus',
          label: this.$t(
            'INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.DISPLAY_NAME_STATUS.LABEL'
          ),
          rawValue: nameStatus || 'UNKNOWN',
          displayValue: humanizeNameStatus(nameStatus, key => this.$t(key)),
          type: 'status',
        },
        {
          key: 'codeVerificationStatus',
          label: this.$t(
            'INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.CODE_VERIFICATION_STATUS.LABEL'
          ),
          rawValue: codeVerificationStatus || 'UNKNOWN',
          displayValue: humanizeVerificationStatus(
            codeVerificationStatus,
            key => this.$t(key)
          ),
          type: 'verification',
        },
        {
          key: 'qualityRating',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.QUALITY_RATING.LABEL'),
          rawValue: qualityRating || 'UNKNOWN',
          displayValue: humanizeQualityRating(qualityRating, key => this.$t(key)),
          type: 'quality',
        },
        {
          key: 'messagingLimitTier',
          label: this.$t(
            'INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.MESSAGING_LIMIT_TIER.LABEL'
          ),
          displayValue: humanizeMessagingLimitTier(
            messagingLimitTier,
            (key, params) => this.$t(key, params)
          ),
        },
        {
          key: 'accountMode',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.ACCOUNT_MODE.LABEL'),
          rawValue: accountMode || 'UNKNOWN',
          displayValue: humanizeAccountMode(accountMode, key => this.$t(key)),
          type: 'mode',
        },
      ];
    },
    showWebhookSection() {
      const webhookConfiguration = this.healthData && this.healthData.webhook_configuration;
      return webhookConfiguration !== undefined;
    },
    webhookUrl() {
      if (!this.healthData || !this.healthData.webhook_configuration) return '';

      const config = this.healthData.webhook_configuration;
      return (
        config.phone_number ||
        config.whatsapp_business_account ||
        config.application ||
        ''
      );
    },
    webhookConfigured() {
      return Boolean(this.webhookUrl);
    },
    webhookUrlMismatch() {
      if (!this.healthData) return false;

      return (
        this.webhookConfigured &&
        this.webhookUrl !== this.healthData.expected_webhook_url
      );
    },
    businessId() {
      return (this.healthData && this.healthData.business_id) || '';
    },
  },
  methods: {
    valueClass(item) {
      if (item.type === 'quality') {
        return QUALITY_COLORS[item.rawValue] || 'text-slate-800 dark:text-slate-100';
      }

      if (item.type === 'status') {
        return STATUS_COLORS[item.rawValue] || 'text-slate-800 dark:text-slate-100';
      }

      if (item.type === 'verification') {
        return (
          VERIFICATION_COLORS[item.rawValue] || 'text-slate-800 dark:text-slate-100'
        );
      }

      if (item.type === 'mode') {
        return MODE_COLORS[item.rawValue] || 'text-slate-800 dark:text-slate-100';
      }

      return 'text-slate-800 dark:text-slate-100';
    },
    openMetaSettings() {
      const businessId = this.businessId;
      const url = businessId
        ? `https://business.facebook.com/latest/whatsapp_manager/phone_numbers/?business_id=${businessId}&tab=phone-numbers`
        : 'https://business.facebook.com/';
      window.open(url, '_blank', 'noopener,noreferrer');
    },
  },
};
</script>

<template>
  <div>
    <WhatsappPricingSummary
      class="mb-6"
      :pricing-data="pricingData"
      :is-loading="isLoadingPricing"
      :error-message="pricingError"
      :error-code="pricingErrorCode"
      :business-id="businessId"
    />

    <SettingsSection
      :title="$t('INBOX_MGMT.ACCOUNT_HEALTH.TITLE')"
      :sub-title="$t('INBOX_MGMT.ACCOUNT_HEALTH.DESCRIPTION')"
    >
      <woot-button variant="smooth" size="small" @click="openMetaSettings">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.GO_TO_SETTINGS') }}
      </woot-button>

      <div v-if="healthItems.length" class="health-grid">
        <div v-for="item in healthItems" :key="item.key" class="health-item">
          <span class="health-item__label">{{ item.label }}</span>
          <span class="health-item__value" :class="valueClass(item)">
            {{ item.displayValue }}
          </span>
        </div>
      </div>
      <p v-else class="health-empty">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.NO_DATA') }}
      </p>

      <p class="health-footnote">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.FOOTNOTE') }}
      </p>
    </SettingsSection>

    <SettingsSection
      v-if="showWebhookSection"
      :title="$t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.TITLE')"
      :sub-title="
        webhookUrlMismatch
          ? $t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.URL_MISMATCH')
          : $t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.DESCRIPTION')
      "
    >
      <p v-if="webhookConfigured" class="health-webhook-url">
        {{ webhookUrl }}
      </p>
      <p v-else class="health-webhook-url">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.ACTION_REQUIRED') }}
      </p>
      <woot-button
        :is-loading="isRegisteringWebhook"
        :disabled="isRegisteringWebhook"
        @click="$emit('registerWebhook')"
      >
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.REGISTER_BUTTON') }}
      </woot-button>
    </SettingsSection>
  </div>
</template>

<style scoped lang="scss">
.health-grid {
  @apply grid grid-cols-1 md:grid-cols-2 gap-3 mt-4;
}

.health-item {
  @apply flex flex-col gap-1 p-3 rounded-md bg-slate-25 dark:bg-slate-900;

  &__label {
    @apply text-xs text-slate-500 dark:text-slate-400;
  }

  &__value {
    @apply text-sm font-medium;
  }
}

.health-empty,
.health-footnote {
  @apply text-sm text-slate-500 dark:text-slate-400 mt-3;
}

.health-footnote {
  @apply text-xs mt-4;
}

.health-webhook-url {
  @apply text-sm text-slate-700 dark:text-slate-200 mb-3 break-all;
}
</style>
