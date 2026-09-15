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
import { mapGetters } from 'vuex';
import { hasPermissions } from 'dashboard/helper/permissionsHelper';
import { BILLING_ROUTE_PERMISSIONS } from 'dashboard/constants/permissions';
import Banner from 'dashboard/components/ui/Banner.vue';
import accountMixin from 'dashboard/mixins/account';
import { isBillingWarning, isBillingLocked } from 'dashboard/helper/billingLock';

export default {
  components: { Banner },
  mixins: [accountMixin],
  computed: {
    ...mapGetters({
      isBillingDeployment: 'globalConfig/isBillingDeployment',
      isManyTalksDeployment: 'globalConfig/isManyTalksDeployment',
      getAccount: 'accounts/getAccount',
      currentUser: 'getCurrentUser',
    }),
    canManageBilling() {
      return hasPermissions(
        BILLING_ROUTE_PERMISSIONS,
        this.currentUser?.permissions
      );
    },
    bannerMessage() {
      return this.$t('GENERAL_SETTINGS.PAYMENT_PENDING');
    },
    actionButtonMessage() {
      return this.$t('GENERAL_SETTINGS.OPEN_BILLING');
    },
    hasLinkedStripeCustomer() {
      const account = this.getAccount(this.accountId);
      return Boolean(account?.custom_attributes?.stripe_customer_id);
    },
    shouldShowBanner() {
      if (!this.isBillingDeployment || !this.canManageBilling) return false;
      if (this.isManyTalksDeployment && !this.hasLinkedStripeCustomer) {
        return false;
      }
      const account = this.getAccount(this.accountId);
      if (isBillingLocked(account)) return false;
      return isBillingWarning(account);
    },
  },
  methods: {
    routeToBilling() {
      this.$router.push({
        name: 'billing_settings_index',
        params: { accountId: this.accountId },
      });
    },
  },
};
</script>
