require 'rails_helper'

RSpec.describe Enterprise::Billing::Lock do
  let(:account) { create(:account) }

  it 'is not locked without a subscription status' do
    expect(described_class.locked?(account)).to be(false)
    expect(account).not_to be_billing_locked
    expect(account).to be_operationally_available
  end

  it 'treats past_due as a warning, not a lock' do
    account.update!(custom_attributes: { 'subscription_status' => 'past_due' })

    expect(described_class.warning?(account)).to be(true)
    expect(account).not_to be_billing_locked
    expect(account).to be_operationally_available
  end

  %w[unpaid canceled incomplete_expired].each do |status|
    it "locks billing when subscription_status is #{status}" do
      account.update!(custom_attributes: { 'subscription_status' => status })

      expect(account).to be_billing_locked
      expect(account).not_to be_operationally_available
      expect(account).to be_active
    end
  end

  it 'is not operationally available when manually suspended' do
    account.update!(status: :suspended)

    expect(account).not_to be_operationally_available
  end
end
