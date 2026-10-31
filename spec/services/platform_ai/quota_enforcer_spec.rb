# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformAi::QuotaEnforcer do
  describe '.sync!' do
    it 'pauses active configs when used credits meet the limit' do
      account = create(:account, ai_credit_limit: 100, ai_credits_used: 100)
      config = create(:ai_attendant_config, account: account, active: true)
      admin_paused = create(:ai_attendant_config, account: account, active: false, pause_reason: 'admin')

      described_class.sync!(account: account)

      expect(config.reload).to have_attributes(active: false, pause_reason: 'no_credits')
      expect(admin_paused.reload).to have_attributes(active: false, pause_reason: 'admin')
    end

    it 'does not change configs when the account is still within quota' do
      account = create(:account, ai_credit_limit: 100, ai_credits_used: 10)
      config = create(:ai_attendant_config, account: account, active: true)

      described_class.sync!(account: account)

      expect(config.reload).to have_attributes(active: true, pause_reason: nil)
    end

    it 'unpauses configs paused for no_credits when the limit allows usage again' do
      account = create(:account, ai_credit_limit: 200, ai_credits_used: 100)
      config = create(:ai_attendant_config, account: account, active: false, pause_reason: 'no_credits')
      admin_paused = create(:ai_attendant_config, account: account, active: false, pause_reason: 'admin')

      described_class.sync!(account: account)

      expect(config.reload).to have_attributes(active: true, pause_reason: nil)
      expect(admin_paused.reload).to have_attributes(active: false, pause_reason: 'admin')
    end
  end
end
