import {
  isBillingLocked,
  isBillingWarning,
} from '../billingLock';

describe('billingLock', () => {
  it('locks unpaid, canceled and incomplete_expired', () => {
    expect(
      isBillingLocked({ custom_attributes: { subscription_status: 'unpaid' } })
    ).toBe(true);
    expect(
      isBillingLocked({
        custom_attributes: { subscription_status: 'canceled' },
      })
    ).toBe(true);
    expect(
      isBillingLocked({
        custom_attributes: { subscription_status: 'incomplete_expired' },
      })
    ).toBe(true);
  });

  it('does not lock past_due', () => {
    expect(
      isBillingLocked({
        custom_attributes: { subscription_status: 'past_due' },
      })
    ).toBe(false);
    expect(
      isBillingWarning({
        custom_attributes: { subscription_status: 'past_due' },
      })
    ).toBe(true);
  });

  it('does not lock active accounts', () => {
    expect(
      isBillingLocked({ custom_attributes: { subscription_status: 'active' } })
    ).toBe(false);
    expect(isBillingLocked({})).toBe(false);
  });
});
