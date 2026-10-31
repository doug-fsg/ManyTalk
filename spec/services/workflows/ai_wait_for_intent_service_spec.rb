# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::AiWaitForIntentService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:workflow) { create(:workflow, account: account) }
  let(:intent) { Workflows::Constants::AI_INTENT_CATALOG.find { |item| item[:key] == 'purchase_intent' } }
  let(:enrollment) do
    create(:workflow_enrollment,
           workflow: workflow,
           account: account,
           conversation: conversation,
           contact: contact,
           status: 'waiting',
           context: {
             'intent_watch' => {
               'node_id' => 'intent_1',
               'intent_key' => 'purchase_intent',
               'deadline_at' => 1.hour.from_now.iso8601(6)
             }
           })
  end
  let(:message) { create(:message, conversation: conversation, message_type: :incoming, content: 'quero comprar agora') }

  subject(:service) { described_class.new(enrollment, message) }

  before do
    account.enable_features!('inteligencia_artificial')
    allow(PlatformAi::QuotaGuard).to receive(:charge!)
  end

  describe '#classify!' do
    it 'does not POST to WORKFLOW_AI_URL' do
      allow(PlatformAi::ChatClient).to receive(:complete)
        .and_return(content: '{"matched":true}', tool_calls: nil, total_tokens: 10)
      webhook_stub = stub_request(:any, /n8n|workflow-ai|example.com/)
      expect(Workflows::AiWebhook).not_to receive(:url)

      result = service.classify!

      expect(webhook_stub).not_to have_been_requested
      expect(result[:matched]).to be true
      expect(result[:ok]).to be true
    end

    it 'sends wait-for-intent contract fields to ChatClient' do
      expect(PlatformAi::ChatClient).to receive(:complete) do |messages:, **|
        user_payload = JSON.parse(messages.find { |m| m[:role] == 'user' }[:content])
        expect(user_payload['event']).to eq('workflow.ai_wait_for_intent')
        expect(user_payload['intent_key']).to eq('purchase_intent')
        expect(user_payload.dig('intent', 'key')).to eq('purchase_intent')
        expect(user_payload.dig('intent', 'description')).to eq(intent[:description])
        expect(user_payload.dig('intent', 'examples')).to eq(intent[:examples])
        expect(user_payload['workflow_id']).to eq(workflow.id)
        expect(user_payload['workflow_node_id']).to eq('intent_1')
        expect(user_payload['enrollment_id']).to eq(enrollment.id)
        expect(user_payload.dig('message', 'content')).to eq('quero comprar agora')
        { content: '{"matched":false}', tool_calls: nil, total_tokens: 8 }
      end

      result = service.classify!
      expect(result[:matched]).to be false
      expect(result[:ok]).to be true
    end

    it 'parses JSON matched true even when wrapped in markdown' do
      allow(PlatformAi::ChatClient).to receive(:complete).and_return(
        content: "```json\n{\"matched\": true}\n```",
        tool_calls: nil,
        total_tokens: 12
      )

      expect(service.classify![:matched]).to be true
    end

    it 'returns matched false when ChatClient fails' do
      allow(PlatformAi::ChatClient).to receive(:complete)
        .and_raise(PlatformAi::ChatClient::RequestError.new('failed', status: 500))

      result = service.classify!
      expect(result[:ok]).to be false
      expect(result[:matched]).to be false
    end

    context 'when feature is disabled' do
      before { account.disable_features!('inteligencia_artificial') }

      it 'returns matched false without calling ChatClient' do
        expect(PlatformAi::ChatClient).not_to receive(:complete)
        expect(service.classify!).to eq(matched: false)
      end
    end

    context 'when quota is exceeded' do
      before { account.update!(ai_credit_limit: 1, ai_credits_used: 1) }

      it 'returns matched false without calling ChatClient' do
        expect(PlatformAi::ChatClient).not_to receive(:complete)
        expect(service.classify!).to eq(matched: false)
      end
    end
  end
end
