# frozen_string_literal: true

module Workflows
  class PlatformAiCompletion
    TOKENS_PER_CREDIT = 1000

    def self.complete(account:, messages:)
      new(account: account, messages: messages).complete
    end

    pattr_initialize [:account!, :messages!]

    def complete
      return { error: :quota_exceeded } unless PlatformAi::QuotaGuard.allow?(account: account)

      result = PlatformAi::ChatClient.complete(messages: messages)
      credits = result[:total_tokens].to_i.to_d / TOKENS_PER_CREDIT
      PlatformAi::QuotaGuard.charge!(account: account, credits: credits)

      { content: result[:content], total_tokens: result[:total_tokens], credits_charged: credits }
    rescue PlatformAi::ChatClient::RequestError => e
      { error: :llm_error, detail: e.message }
    end
  end
end
