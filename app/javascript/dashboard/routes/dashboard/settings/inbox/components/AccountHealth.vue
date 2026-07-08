<script>
import SettingsSection from 'dashboard/components/SettingsSection.vue';

const QUALITY_COLORS = {
  GREEN: 'text-green-600',
  YELLOW: 'text-amber-600',
  RED: 'text-red-600',
};

const STATUS_COLORS = {
  APPROVED: 'text-green-600',
  PENDING_REVIEW: 'text-amber-600',
  REJECTED: 'text-red-600',
};

export default {
  components: { SettingsSection },
  props: {
    healthData: {
      type: Object,
      default: null,
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
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.DISPLAY_PHONE_NUMBER.LABEL'),
          value: displayPhoneNumber || '—',
        },
        {
          key: 'verifiedName',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.VERIFIED_NAME.LABEL'),
          value: verifiedName || '—',
        },
        {
          key: 'displayNameStatus',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.DISPLAY_NAME_STATUS.LABEL'),
          value: nameStatus || 'UNKNOWN',
          type: 'status',
        },
        {
          key: 'codeVerificationStatus',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.CODE_VERIFICATION_STATUS.LABEL'),
          value: codeVerificationStatus || 'UNKNOWN',
        },
        {
          key: 'qualityRating',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.QUALITY_RATING.LABEL'),
          value: qualityRating || 'UNKNOWN',
          type: 'quality',
        },
        {
          key: 'messagingLimitTier',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.MESSAGING_LIMIT_TIER.LABEL'),
          value: messagingLimitTier || '—',
        },
        {
          key: 'accountMode',
          label: this.$t('INBOX_MGMT.ACCOUNT_HEALTH.FIELDS.ACCOUNT_MODE.LABEL'),
          value: accountMode || 'UNKNOWN',
          type: 'mode',
        },
      ];
    },
    showWebhookSection() {
      return this.healthData?.webhook_configuration !== undefined;
    },
    webhookUrl() {
      return (
        this.healthData?.webhook_configuration?.phone_number ||
        this.healthData?.webhook_configuration?.whatsapp_business_account ||
        this.healthData?.webhook_configuration?.application
      );
    },
    webhookConfigured() {
      return Boolean(this.webhookUrl);
    },
    webhookUrlMismatch() {
      return (
        this.webhookConfigured &&
        this.webhookUrl !== this.healthData?.expected_webhook_url
      );
    },
  },
  methods: {
    qualityClass(rating) {
      return QUALITY_COLORS[rating] || 'text-slate-700 dark:text-slate-200';
    },
    statusClass(status) {
      return STATUS_COLORS[status] || 'text-slate-700 dark:text-slate-200';
    },
    openMetaSettings() {
      const businessId = this.healthData?.business_id;
      const url = businessId
        ? `https://business.facebook.com/latest/whatsapp_manager/phone_numbers/?business_id=${businessId}&tab=phone-numbers`
        : 'https://business.facebook.com/';
      window.open(url, '_blank');
    },
  },
};
</script>

<template>
  <div>
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
          <span
            class="health-item__value"
            :class="
              item.type === 'quality'
                ? qualityClass(item.value)
                : item.type === 'status'
                  ? statusClass(item.value)
                  : ''
            "
          >
            {{ item.value }}
          </span>
        </div>
      </div>
      <p v-else class="health-empty">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.NO_DATA') }}
      </p>
    </SettingsSection>

    <SettingsSection
      v-if="showWebhookSection"
      :title="$t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.TITLE')"
      :sub-title="
        webhookUrlMismatch
          ? $t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.URL_MISMATCH')
          : $t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.ACTION_REQUIRED')
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
    @apply text-sm font-medium text-slate-800 dark:text-slate-100;
  }
}

.health-empty {
  @apply text-sm text-slate-500 dark:text-slate-400 mt-3;
}

.health-webhook-url {
  @apply text-sm text-slate-700 dark:text-slate-200 mb-3 break-all;
}
</style>
