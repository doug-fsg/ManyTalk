import { computed } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { hasPermissions } from 'dashboard/helper/permissionsHelper';
import { BILLING_ROUTE_PERMISSIONS } from 'dashboard/constants/permissions';
import {
  isBillingLocked,
  isBillingWarning,
} from 'dashboard/helper/billingLock';

export function useBillingAccess() {
  const getters = useStoreGetters();
  const { accountId } = useAccount();

  const currentAccount = computed(
    () => getters['accounts/getAccount'].value(accountId.value) || {}
  );
  const currentUser = computed(() => getters.getCurrentUser.value || {});
  const canManageBilling = computed(() =>
    hasPermissions(BILLING_ROUTE_PERMISSIONS, currentUser.value.permissions)
  );
  const billingLocked = computed(() => isBillingLocked(currentAccount.value));
  const billingWarning = computed(() => isBillingWarning(currentAccount.value));

  return {
    accountId,
    currentAccount,
    canManageBilling,
    billingLocked,
    billingWarning,
  };
}
