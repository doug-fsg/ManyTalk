<template>
  <banner
    v-if="shouldShowBanner"
    color-scheme="alert"
    :banner-message="bannerMessage"
    :action-button-label="actionButtonMessage"
    has-action-button
    @click="routeToBilling"
  />
</template>

<script>
import Banner from 'dashboard/components/ui/Banner.vue';
import { mapGetters } from 'vuex';
import accountMixin from 'dashboard/mixins/account';
import { differenceInDays } from 'date-fns';

export default {
  components: { Banner },
  mixins: [accountMixin],
  data() {
    return { conversationMeta: {} };
  },
  computed: {
    ...mapGetters({
      isBillingDeployment: 'globalConfig/isBillingDeployment',
      isManyTalksDeployment: 'globalConfig/isManyTalksDeployment',
      getAccount: 'accounts/getAccount',
    }),
    bannerMessage() {
      return this.$t('GENERAL_SETTINGS.LIMITS_UPGRADE');
    },
    actionButtonMessage() {
      return this.$t('GENERAL_SETTINGS.OPEN_BILLING');
    },
    hasLinkedStripeCustomer() {
      const account = this.getAccount(this.accountId);
      return Boolean(account?.custom_attributes?.stripe_customer_id);
    },
    shouldShowBanner() {
      if (!this.isBillingDeployment || this.isTrialAccount()) return false;
      if (this.isManyTalksDeployment && !this.hasLinkedStripeCustomer) {
        return false;
      }
      return this.isLimitExceeded();
    },
  },
  mounted() {
    if (
      this.isBillingDeployment &&
      (!this.isManyTalksDeployment || this.hasLinkedStripeCustomer)
    ) {
      this.fetchLimits();
    }
  },
  methods: {
    fetchLimits() {
      this.$store.dispatch('accounts/limits');
    },
    routeToBilling() {
      this.$router.push({
        name: 'billing_settings_index',
        params: { accountId: this.accountId },
      });
    },
    isTrialAccount() {
      // check if account is less than 15 days old
      const account = this.getAccount(this.accountId);
      if (!account) return false;

      const createdAt = new Date(account.created_at);

      const diffDays = differenceInDays(new Date(), createdAt);

      return diffDays <= 15;
    },
    isLimitExceeded() {
      const account = this.getAccount(this.accountId);
      if (!account) return false;

      const { limits } = account;
      if (!limits) return false;

      const { conversation, non_web_inboxes: nonWebInboxes } = limits;
      return this.testLimit(conversation) || this.testLimit(nonWebInboxes);
    },
    testLimit({ allowed, consumed }) {
      return consumed > allowed;
    },
  },
};
</script>
