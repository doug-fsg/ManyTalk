export const BILLING_LOCK_STATUSES = [
  'unpaid',
  'canceled',
  'incomplete_expired',
];
export const BILLING_WARNING_STATUSES = ['past_due', 'incomplete'];

export const subscriptionStatus = (account = {}) =>
  account?.custom_attributes?.subscription_status || '';

export const isBillingLocked = (account = {}) =>
  BILLING_LOCK_STATUSES.includes(subscriptionStatus(account));

export const isBillingWarning = (account = {}) =>
  BILLING_WARNING_STATUSES.includes(subscriptionStatus(account));
