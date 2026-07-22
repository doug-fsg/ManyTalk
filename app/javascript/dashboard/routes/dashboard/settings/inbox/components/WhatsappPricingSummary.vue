<template>
  <SettingsSection
    :title="$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.TITLE')"
    :sub-title="$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.DESCRIPTION')"
  >
    <div class="pricing-actions">
      <woot-button variant="smooth" size="small" @click="openMetaBilling">
        {{ billingButtonLabel }}
      </woot-button>
    </div>

    <div v-if="isLoading" class="pricing-loading">
      <spinner size="small" />
      <span>{{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.LOADING') }}</span>
    </div>

    <div v-else-if="isPartnerBilling" class="pricing-alert pricing-alert--info">
      <p class="pricing-alert__title">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.PARTNER_BILLING.TITLE') }}
      </p>
      <p class="pricing-alert__body">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.PARTNER_BILLING.BODY') }}
      </p>
      <ul class="pricing-alert__list">
        <li>{{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.PARTNER_BILLING.STEP_1') }}</li>
        <li>{{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.PARTNER_BILLING.STEP_2') }}</li>
      </ul>
    </div>

    <div v-else-if="errorMessage" class="pricing-alert">
      <p class="pricing-alert__title">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.LOAD_ERROR') }}
      </p>
      <p class="pricing-alert__body">{{ errorMessage }}</p>
    </div>

    <div v-else-if="hasData" class="pricing-content">
      <div class="pricing-summary">
        <div class="pricing-summary__item">
          <span class="pricing-summary__label">
            {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.TOTAL_COST') }}
          </span>
          <span class="pricing-summary__value">
            {{ formattedTotalCost }}
          </span>
        </div>
        <div class="pricing-summary__item">
          <span class="pricing-summary__label">
            {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.TOTAL_VOLUME') }}
          </span>
          <span class="pricing-summary__value">
            {{ pricingData.total_volume }}
          </span>
        </div>
        <div class="pricing-summary__item">
          <span class="pricing-summary__label">
            {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.PERIOD') }}
          </span>
          <span class="pricing-summary__value pricing-summary__value--muted">
            {{ formattedPeriod }}
          </span>
        </div>
      </div>

      <div v-if="categoryItems.length" class="pricing-categories">
        <div
          v-for="item in categoryItems"
          :key="item.key"
          class="pricing-category"
        >
          <span class="pricing-category__label">{{ item.label }}</span>
          <span class="pricing-category__value">
            {{ formatCost(item.cost) }} · {{ item.volume }}
            {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.MESSAGES') }}
          </span>
        </div>
      </div>

      <p class="pricing-note">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.META_NOTE') }}
      </p>
    </div>

    <p v-else class="pricing-empty">
      {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.NO_DATA') }}
    </p>
  </SettingsSection>
</template>

<script>
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import Spinner from 'shared/components/Spinner.vue';
import { isPartnerBillingError } from 'dashboard/helper/whatsappHealthLabels';

const CATEGORY_I18N_KEYS = {
  MARKETING: 'INBOX_MGMT.ACCOUNT_HEALTH.PRICING.CATEGORIES.MARKETING',
  UTILITY: 'INBOX_MGMT.ACCOUNT_HEALTH.PRICING.CATEGORIES.UTILITY',
  AUTHENTICATION: 'INBOX_MGMT.ACCOUNT_HEALTH.PRICING.CATEGORIES.AUTHENTICATION',
  AUTHENTICATION_INTERNATIONAL:
    'INBOX_MGMT.ACCOUNT_HEALTH.PRICING.CATEGORIES.AUTHENTICATION_INTERNATIONAL',
  SERVICE: 'INBOX_MGMT.ACCOUNT_HEALTH.PRICING.CATEGORIES.SERVICE',
  MARKETING_LITE: 'INBOX_MGMT.ACCOUNT_HEALTH.PRICING.CATEGORIES.MARKETING_LITE',
  REFERRAL_CONVERSION:
    'INBOX_MGMT.ACCOUNT_HEALTH.PRICING.CATEGORIES.REFERRAL_CONVERSION',
  UNKNOWN: 'INBOX_MGMT.ACCOUNT_HEALTH.PRICING.CATEGORIES.UNKNOWN',
};

export default {
  components: {
    SettingsSection,
    Spinner,
  },
  props: {
    pricingData: {
      type: Object,
      default: null,
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
    errorMessage: {
      type: String,
      default: '',
    },
    errorCode: {
      type: String,
      default: '',
    },
    businessId: {
      type: String,
      default: '',
    },
  },
  computed: {
    hasData() {
      return Boolean(this.pricingData);
    },
    isPartnerBilling() {
      return isPartnerBillingError(this.errorMessage, this.errorCode);
    },
    billingButtonLabel() {
      if (this.isPartnerBilling) {
        return this.$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.PARTNER_BILLING.CTA');
      }

      return this.$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.VIEW_BILLING');
    },
    categoryItems() {
      const categories = (this.pricingData && this.pricingData.categories) || [];

      return categories.map(category => ({
        ...category,
        label: this.$t(
          CATEGORY_I18N_KEYS[category.key] || CATEGORY_I18N_KEYS.UNKNOWN
        ),
      }));
    },
    formattedTotalCost() {
      if (!this.pricingData || !this.pricingData.cost_available) {
        return this.$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.UNAVAILABLE');
      }

      return this.formatCost(this.pricingData.total_cost);
    },
    formattedPeriod() {
      if (!this.pricingData || !this.pricingData.period_start || !this.pricingData.period_end) {
        return '—';
      }

      const start = new Date(this.pricingData.period_start);
      const end = new Date(this.pricingData.period_end);
      const formatter = new Intl.DateTimeFormat(this.$i18n.locale, {
        day: '2-digit',
        month: 'short',
      });

      return `${formatter.format(start)} - ${formatter.format(end)}`;
    },
  },
  methods: {
    formatCost(value) {
      const amount = Number(value || 0);
      return new Intl.NumberFormat(this.$i18n.locale, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 4,
      }).format(amount);
    },
    openMetaBilling() {
      const pricingBusinessId =
        this.pricingData && this.pricingData.business_id
          ? this.pricingData.business_id
          : '';
      const businessId = this.businessId || pricingBusinessId;
      const url = businessId
        ? `https://business.facebook.com/billing_hub/accounts?business_id=${businessId}`
        : 'https://business.facebook.com/billing_hub';

      window.open(url, '_blank', 'noopener,noreferrer');
    },
  },
};
</script>

<style scoped lang="scss">
.pricing-actions {
  @apply mb-4;
}

.pricing-loading {
  @apply flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400 mt-3;
}

.pricing-alert {
  @apply mt-3 p-4 rounded-md bg-amber-50 dark:bg-amber-900/20 border border-amber-100 dark:border-amber-800 text-sm text-amber-900 dark:text-amber-100;

  &--info {
    @apply bg-slate-25 dark:bg-slate-900 border-slate-75 dark:border-slate-700 text-slate-700 dark:text-slate-200;
  }

  &__title {
    @apply font-medium text-slate-800 dark:text-slate-100 mb-1;
  }

  &__body {
    @apply text-sm leading-relaxed;
  }

  &__list {
    @apply mt-3 space-y-1 text-sm list-disc pl-5;
  }
}

.pricing-content {
  @apply mt-4;
}

.pricing-summary {
  @apply grid grid-cols-1 md:grid-cols-3 gap-3;

  &__item {
    @apply flex flex-col gap-1 p-3 rounded-md bg-slate-25 dark:bg-slate-900;
  }

  &__label {
    @apply text-xs text-slate-500 dark:text-slate-400;
  }

  &__value {
    @apply text-lg font-semibold text-slate-800 dark:text-slate-100;

    &--muted {
      @apply text-sm font-medium;
    }
  }
}

.pricing-categories {
  @apply mt-4 grid grid-cols-1 gap-2;
}

.pricing-category {
  @apply flex flex-col md:flex-row md:items-center md:justify-between gap-1 p-3 rounded-md border border-slate-75 dark:border-slate-700;

  &__label {
    @apply text-sm font-medium text-slate-800 dark:text-slate-100;
  }

  &__value {
    @apply text-sm text-slate-500 dark:text-slate-400;
  }
}

.pricing-note,
.pricing-empty {
  @apply text-xs text-slate-500 dark:text-slate-400 mt-4;
}

.pricing-empty {
  @apply text-sm mt-3;
}
</style>
