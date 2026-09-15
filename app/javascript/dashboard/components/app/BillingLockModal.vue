<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useRouter, useRoute } from 'dashboard/composables/route';
import { useBillingAccess } from 'dashboard/composables/useBillingAccess';

const props = defineProps({
  accountSwitcherOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['switch-account']);

const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const { accountId, canManageBilling, billingLocked } = useBillingAccess();

const isOnBillingPage = computed(
  () => route.name === 'billing_settings_index'
);
const show = computed(
  () =>
    billingLocked.value &&
    !isOnBillingPage.value &&
    !props.accountSwitcherOpen
);
const title = computed(() =>
  canManageBilling.value
    ? t('GENERAL_SETTINGS.BILLING_LOCK.TITLE_MANAGER')
    : t('GENERAL_SETTINGS.BILLING_LOCK.TITLE_AGENT')
);
const message = computed(() =>
  canManageBilling.value
    ? t('GENERAL_SETTINGS.BILLING_LOCK.MESSAGE_MANAGER')
    : t('GENERAL_SETTINGS.BILLING_LOCK.MESSAGE_AGENT')
);

const goToBilling = () => {
  router.push({
    name: 'billing_settings_index',
    params: { accountId: accountId.value },
  });
};

const switchAccount = () => {
  emit('switch-account');
};
</script>

<template>
  <woot-modal
    :show="show"
    :show-close-button="false"
    :close-on-backdrop-click="false"
    :on-close="() => {}"
  >
    <div class="billing-lock-modal">
      <header class="billing-lock-modal__header">
        <span class="billing-lock-modal__badge" aria-hidden="true">
          <fluent-icon icon="lock-closed" size="20" />
        </span>
        <h2 class="billing-lock-modal__title">
          {{ title }}
        </h2>
      </header>
      <div class="billing-lock-modal__body">
        <p class="billing-lock-modal__copy">
          {{ message }}
        </p>
        <div class="billing-lock-modal__actions">
          <woot-button
            v-if="canManageBilling"
            color-scheme="primary"
            @click="goToBilling"
          >
            {{ $t('GENERAL_SETTINGS.BILLING_LOCK.OPEN_BILLING') }}
          </woot-button>
          <woot-button
            :color-scheme="canManageBilling ? 'secondary' : 'primary'"
            :variant="canManageBilling ? 'smooth' : 'solid'"
            @click="switchAccount"
          >
            {{ $t('GENERAL_SETTINGS.BILLING_LOCK.SWITCH_ACCOUNT') }}
          </woot-button>
        </div>
      </div>
    </div>
  </woot-modal>
</template>

<style scoped lang="scss">
.billing-lock-modal {
  @apply overflow-hidden;
}

.billing-lock-modal__header {
  @apply flex flex-col items-center justify-center gap-3 px-8 py-6 bg-red-600 dark:bg-red-700 text-white;
}

.billing-lock-modal__badge {
  @apply flex items-center justify-center w-10 h-10 rounded-full bg-white bg-opacity-10 text-white;
}

.billing-lock-modal__title {
  @apply m-0 text-xl font-semibold tracking-[-0.02em] leading-6 text-center text-white;
}

.billing-lock-modal__body {
  @apply flex flex-col items-center px-8 pt-6 pb-8 text-center;
}

.billing-lock-modal__copy {
  @apply m-0 max-w-[22rem] text-sm leading-6 text-slate-600 dark:text-slate-300;
}

.billing-lock-modal__actions {
  @apply flex flex-wrap items-center justify-center gap-2 mt-6;
}
</style>
