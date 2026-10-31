# frozen_string_literal: true

module PlatformAi
  class QuotaEnforcer
    def self.sync!(account:)
      if QuotaGuard.allow?(account: account)
        unpause_no_credits!(account)
      else
        pause_for_no_credits!(account)
      end
    end

    def self.pause_for_no_credits!(account)
      account.ai_attendant_configs.where(active: true).find_each do |config|
        config.update!(active: false, pause_reason: 'no_credits')
      end
    end

    def self.unpause_no_credits!(account)
      account.ai_attendant_configs.where(pause_reason: 'no_credits').find_each do |config|
        config.update!(active: true, pause_reason: nil)
      end
    end
    private_class_method :pause_for_no_credits!, :unpause_no_credits!
  end
end
