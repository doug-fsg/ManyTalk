# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ActivityLogger do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:workflow) { create(:workflow, account: account, name: 'Follow-up 24h') }
  let(:user) { create(:user, account: account, name: 'Maria') }

  describe '.actor_name' do
    it 'returns workflow name for Workflow' do
      expect(described_class.actor_name(workflow)).to eq('Follow-up 24h')
    end

    it 'returns Automation System for AutomationRule' do
      rule = create(:automation_rule, account: account)
      expect(described_class.actor_name(rule)).to eq('Automation System')
    end

    it 'returns nil for other objects' do
      expect(described_class.actor_name(nil)).to be_nil
    end
  end

  describe '.log_started' do
    it 'logs manual start with user name' do
      expect(Conversations::ActivityMessageJob).to receive(:perform_later).with(
        conversation,
        hash_including(
          message_type: :activity,
          content: a_string_including('Maria').and(including('Follow-up 24h'))
        )
      )

      described_class.log_started(conversation, workflow, user: user)
    end

    it 'logs automatic start without user' do
      expect(Conversations::ActivityMessageJob).to receive(:perform_later).with(
        conversation,
        hash_including(
          content: a_string_including('Follow-up 24h').and(matching(/automaticamente|automatically/i))
        )
      )

      described_class.log_started(conversation, workflow)
    end
  end

  describe '.log_cancelled' do
    it 'includes reason for automatic cancel' do
      expect(Conversations::ActivityMessageJob).to receive(:perform_later).with(
        conversation,
        hash_including(
          content: a_string_matching(/contato respondeu|contact replied/i)
        )
      )

      described_class.log_cancelled(conversation, workflow, reason: 'contact_replied')
    end
  end
end
