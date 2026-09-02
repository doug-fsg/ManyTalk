<script setup>
import { computed } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useI18n } from 'dashboard/composables/useI18n';
import { useAlert } from 'dashboard/composables';
import { formatBillingDate } from 'dashboard/helper/localeDateHelper';
import { openSupportChat } from 'dashboard/helper/supportChatHelper';
import BillingCard from './components/BillingCard.vue';
import BillingHeader from './components/BillingHeader.vue';
import DetailItem from './components/DetailItem.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const WARNING_STATUSES = ['past_due', 'unpaid', 'incomplete'];

const store = useStore();
const { accountId } = useAccount();
const { t, locale, te } = useI18n();
const getAccount = useMapGetter('accounts/getAccount');
const uiFlags = useMapGetter('accounts/getUIFlags');
const globalConfig = useMapGetter('globalConfig/get');

const currentAccount = computed(
  () => getAccount.value(accountId.value) || {}
);
const customAttributes = computed(
  () => currentAccount.value.custom_attributes || {}
);
const planName = computed(() => customAttributes.value.plan_name || '');
const subscribedQuantity = computed(
  () => customAttributes.value.subscribed_quantity
);
const subscriptionStatus = computed(
  () => customAttributes.value.subscription_status || ''
);
const hasABillingPlan = computed(() => !!planName.value);
const hasSupportChat = computed(() => !!globalConfig.value.chatwootInboxToken);

const subscriptionEndsOn = computed(() => {
  if (!customAttributes.value.subscription_ends_on) return '';
  return formatBillingDate(
    customAttributes.value.subscription_ends_on,
    locale.value
  );
});

const subscriptionStatusLabel = computed(() => {
  if (!subscriptionStatus.value) return '';

  const key = `BILLING_SETTINGS.CURRENT_PLAN.STATUS_OPTIONS.${subscriptionStatus.value}`;
  return te(key) ? t(key) : subscriptionStatus.value;
});

const subscriptionDateLabel = computed(() => {
  if (WARNING_STATUSES.includes(subscriptionStatus.value)) {
    return t('BILLING_SETTINGS.CURRENT_PLAN.DUE_ON');
  }

  if (subscriptionStatus.value === 'canceled') {
    return t('BILLING_SETTINGS.CURRENT_PLAN.ENDED_ON');
  }

  return t('BILLING_SETTINGS.CURRENT_PLAN.RENEWS_ON');
});

const isWarningStatus = computed(() =>
  WARNING_STATUSES.includes(subscriptionStatus.value)
);

const onClickBillingPortal = () => {
  store.dispatch('accounts/checkout');
};

const onToggleChatWindow = () => {
  if (openSupportChat()) return;

  useAlert(t('BILLING_SETTINGS.CHAT_WITH_US.UNAVAILABLE'));
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetchingItem"
    :loading-message="$t('ATTRIBUTES_MGMT.LOADING')"
    :no-records-found="!hasABillingPlan"
    :no-records-message="$t('BILLING_SETTINGS.NO_BILLING_USER')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('BILLING_SETTINGS.TITLE')"
        :description="$t('BILLING_SETTINGS.DESCRIPTION')"
        feature-name="billing"
      />
    </template>
    <template #body>
      <section class="grid gap-4">
        <BillingCard
          :title="$t('BILLING_SETTINGS.MANAGE_SUBSCRIPTION.TITLE')"
          :description="$t('BILLING_SETTINGS.MANAGE_SUBSCRIPTION.DESCRIPTION')"
        >
          <template #action>
            <woot-button size="small" @click="onClickBillingPortal">
              {{ $t('BILLING_SETTINGS.MANAGE_SUBSCRIPTION.BUTTON_TXT') }}
            </woot-button>
          </template>
          <div
            v-if="
              planName ||
              subscribedQuantity ||
              subscriptionEndsOn ||
              subscriptionStatusLabel
            "
            class="grid lg:grid-cols-4 sm:grid-cols-2 grid-cols-1 gap-4 sm:gap-2 sm:divide-x sm:divide-slate-75 sm:dark:divide-slate-700/50"
          >
            <DetailItem
              v-if="planName"
              :label="$t('BILLING_SETTINGS.CURRENT_PLAN.TITLE')"
              :value="planName"
            />
            <DetailItem
              v-if="subscribedQuantity"
              :label="$t('BILLING_SETTINGS.CURRENT_PLAN.SEAT_COUNT')"
              :value="subscribedQuantity"
            />
            <DetailItem
              v-if="subscriptionEndsOn"
              :label="subscriptionDateLabel"
              :value="subscriptionEndsOn"
              :variant="isWarningStatus ? 'warning' : 'default'"
            />
            <DetailItem
              v-if="subscriptionStatusLabel"
              :label="$t('BILLING_SETTINGS.CURRENT_PLAN.STATUS')"
              :value="subscriptionStatusLabel"
              :variant="isWarningStatus ? 'warning' : 'default'"
            />
          </div>
        </BillingCard>

        <BillingHeader
          v-if="hasSupportChat"
          class="px-1 mt-2"
          :title="$t('BILLING_SETTINGS.CHAT_WITH_US.TITLE')"
          :description="$t('BILLING_SETTINGS.CHAT_WITH_US.DESCRIPTION')"
        >
          <woot-button
            size="small"
            color-scheme="secondary"
            icon="chat-multiple"
            @click="onToggleChatWindow"
          >
            {{ $t('BILLING_SETTINGS.CHAT_WITH_US.BUTTON_TXT') }}
          </woot-button>
        </BillingHeader>
      </section>
    </template>
  </SettingsLayout>
</template>
