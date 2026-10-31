# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformAi::QuotaGuard do
  describe '.allow?' do
    it 'returns true when the account has no credit limit' do
      account = create(:account, ai_credit_limit: nil, ai_credits_used: 999)

      expect(described_class.allow?(account: account)).to be(true)
    end

    it 'returns true when used credits are below the limit' do
      account = create(:account, ai_credit_limit: 10, ai_credits_used: 9.99)

      expect(described_class.allow?(account: account)).to be(true)
    end

    it 'returns false when used credits equal the limit' do
      account = create(:account, ai_credit_limit: 10, ai_credits_used: 10)

      expect(described_class.allow?(account: account)).to be(false)
    end

    it 'returns false when used credits exceed the limit' do
      account = create(:account, ai_credit_limit: 10, ai_credits_used: 12.5)

      expect(described_class.allow?(account: account)).to be(false)
    end

    it 'returns false when the account limit is 100 and used is 100' do
      account = create(:account, ai_credit_limit: 100, ai_credits_used: 100)

      expect(described_class.allow?(account: account)).to be(false)
    end
  end

  describe '.charge!' do
    it 'increments ai_credits_used by the given credits' do
      account = create(:account, ai_credit_limit: 100, ai_credits_used: 1.25)

      described_class.charge!(account: account, credits: 0.75)
      account.reload

      expect(account.ai_credits_used).to eq(2.0)
    end

    it 'pauses active configs after charging up to the limit' do
      account = create(:account, ai_credit_limit: 100, ai_credits_used: 99)
      config = create(:ai_attendant_config, account: account, active: true)

      described_class.charge!(account: account, credits: 1)

      expect(config.reload).to have_attributes(active: false, pause_reason: 'no_credits')
    end
  end
end

