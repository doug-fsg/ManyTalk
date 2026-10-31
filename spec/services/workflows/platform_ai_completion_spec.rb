# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::PlatformAiCompletion do
  let(:account) { create(:account, ai_credit_limit: 10, ai_credits_used: 0) }
  let(:messages) { [{ role: 'user', content: 'ping' }] }

  describe '.complete' do
    it 'delegates to ChatClient and charges tokens as credits' do
      allow(PlatformAi::ChatClient).to receive(:complete)
        .with(messages: messages)
        .and_return(content: 'pong', tool_calls: nil, total_tokens: 2000)
      expect(PlatformAi::QuotaGuard).to receive(:charge!).with(account: account, credits: 2)

      result = described_class.complete(account: account, messages: messages)
      expect(result[:content]).to eq('pong')
      expect(result[:error]).to be_nil
    end

    it 'skips ChatClient when quota is exceeded' do
      account.update!(ai_credits_used: 10)
      expect(PlatformAi::ChatClient).not_to receive(:complete)

      result = described_class.complete(account: account, messages: messages)
      expect(result[:error]).to eq(:quota_exceeded)
    end
  end
end
