# frozen_string_literal: true

module PlatformAi
  class QuotaGuard
    def self.allow?(account:)
      limit = account.ai_credit_limit
      return true if limit.nil?

      account.ai_credits_used.to_d < limit.to_d
    end

    def self.charge!(account:, credits:)
      account.increment!(:ai_credits_used, credits.to_d)
      QuotaEnforcer.sync!(account: account)
    end
  end
end
