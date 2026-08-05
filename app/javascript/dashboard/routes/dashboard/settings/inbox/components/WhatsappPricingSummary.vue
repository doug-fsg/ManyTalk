<template>
  <SettingsSection
    :title="sectionTitle"
    :sub-title="sectionDescription"
  >
    <div class="pricing-actions">
      <woot-button variant="smooth" size="small" @click="openMetaBilling">
        {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.VIEW_BILLING') }}
      </woot-button>
    </div>

    <div v-if="isLoading" class="pricing-loading">
      <spinner size="small" />
      <span>{{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.LOADING') }}</span>
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
            {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.TOTAL_VOLUME') }}
          </span>
          <span class="pricing-summary__value">
            {{ pricingData.total_volume }}
          </span>
        </div>
        <div v-if="showCost" class="pricing-summary__item">
          <span class="pricing-summary__label">
            {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.TOTAL_COST') }}
          </span>
          <span class="pricing-summary__value">
            {{ formattedTotalCost }}
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
            <template v-if="showCost">
              {{ formatCost(item.cost) }} · {{ item.volume }}
            </template>
            <template v-else>
              {{ item.volume }}
            </template>
            {{ $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.MESSAGES') }}
          </span>
        </div>
      </div>

      <p class="pricing-note">
        {{ showCost ? $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.META_NOTE') : $t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.VOLUME_NOTE') }}
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
import { buildWhatsAppBillingUrl } from 'dashboard/constants/whatsappTemplateGuide';

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
    wabaId: {
      type: String,
      default: '',
    },
  },
  computed: {
    hasData() {
      return Boolean(this.pricingData);
    },
    showCost() {
      return Boolean(this.pricingData?.cost_available);
    },
    sectionTitle() {
      return this.showCost
        ? this.$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.TITLE')
        : this.$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.USAGE_TITLE');
    },
    sectionDescription() {
      return this.showCost
        ? this.$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.DESCRIPTION')
        : this.$t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.USAGE_DESCRIPTION');
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
      return this.formatCost(this.pricingData?.total_cost);
    },
    formattedPeriod() {
      if (!this.pricingData?.period_start || !this.pricingData?.period_end) {
        return '—';
      }

      const start = new Date(this.pricingData.period_start);
      const end = new Date(this.pricingData.period_end);
      const formatter = new Intl.DateTimeFormat(this.intlLocale, {
        day: '2-digit',
        month: 'short',
      });

      return `${formatter.format(start)} - ${formatter.format(end)}`;
    },
    intlLocale() {
      return (this.$i18n.locale || 'en').replace(/_/g, '-');
    },
  },
  methods: {
    formatCost(value) {
      const amount = Number(value || 0);
      return new Intl.NumberFormat(this.intlLocale, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 4,
      }).format(amount);
    },
    openMetaBilling() {
      const wabaId = this.wabaId || this.pricingData?.waba_id || '';
      window.open(buildWhatsAppBillingUrl(wabaId), '_blank', 'noopener,noreferrer');
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

  &__title {
    @apply font-medium mb-1;
  }

  &__body {
    @apply text-sm leading-relaxed;
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
