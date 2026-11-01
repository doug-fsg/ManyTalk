# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::AiOutreachService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'João Silva') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
  end
  let(:workflow) { create(:workflow, account: account) }
  let(:enrollment) do
    create(:workflow_enrollment, workflow: workflow, conversation: conversation, account: account, current_node_id: 'ai_1')
  end
  let(:node) do
    {
      'id' => 'ai_1',
      'type' => 'ai_outreach',
      'data' => {
        'objective_preset' => 'reengagement',
        'tone_preset' => 'friendly',
        'prompt' => 'Retome o contato com o cliente de forma amigável.',
        'prompt_customized' => false,
        'language' => 'client',
        'include_last_messages' => true
      }
    }
  end
  let(:generated_text) { 'Oi João, que tal retomarmos o assunto?' }
  let(:chat_result) { { content: generated_text, tool_calls: nil, total_tokens: 1000 } }

  subject(:service) do
    described_class.new(
      workflow: workflow,
      enrollment: enrollment,
      conversation: conversation,
      node: node
    )
  end

  before do
    account.enable_features!('inteligencia_artificial', 'atendimento_ia_nativo')
    allow(PlatformAi::ChatClient).to receive(:complete).and_return(chat_result)
    allow(PlatformAi::QuotaGuard).to receive(:allow?).and_call_original
    allow(PlatformAi::QuotaGuard).to receive(:charge!)
  end

  describe '#perform!' do
    it 'does not enqueue WORKFLOW_AI_URL webhook' do
      expect(WebhookJob).not_to receive(:perform_later)
      expect(Workflows::AiWebhook).not_to receive(:url)

      result = service.perform!
      expect(result[:success]).to be true
    end

    it 'sends ChatClient text as a public outgoing message' do
      expect { service.perform! }.to change { conversation.messages.where(private: false).count }.by(1)
      message = conversation.messages.where(private: false).last
      expect(message.content).to eq(generated_text)
      expect(message.message_type).to eq('outgoing')
    end

    it 'calls ChatClient with tone prefix, prompt and outreach contract fields' do
      expect(PlatformAi::ChatClient).to receive(:complete) do |messages:, **|
        user_payload = JSON.parse(messages.find { |m| m[:role] == 'user' }[:content])
        expect(user_payload['event']).to eq('workflow.ai_outreach')
        expect(user_payload['prompt']).to include('Tom amigável e próximo.', 'cliente')
        expect(user_payload['account_id']).to eq(account.id)
        expect(user_payload['workflow_id']).to eq(workflow.id)
        expect(user_payload['workflow_node_id']).to eq('ai_1')
        expect(user_payload['enrollment_id']).to eq(enrollment.id)
        expect(user_payload['ai_config']).to include(
          'objective_preset' => 'reengagement',
          'tone_preset' => 'friendly',
          'language' => 'client',
          'include_last_messages' => true
        )
        chat_result
      end

      service.perform!
    end

    it 'includes the selected inbox_id in the ChatClient payload' do
      node['data']['inbox_id'] = inbox.id

      expect(PlatformAi::ChatClient).to receive(:complete) do |messages:, **|
        user_payload = JSON.parse(messages.find { |m| m[:role] == 'user' }[:content])
        expect(user_payload['inbox_id']).to eq(inbox.id)
        expect(user_payload.dig('ai_config', 'inbox_id')).to eq(inbox.id)
        chat_result
      end

      service.perform!
    end

    it 'sends only interpolated prompt when prompt_customized is true' do
      node['data']['prompt_customized'] = true

      expect(PlatformAi::ChatClient).to receive(:complete) do |messages:, **|
        user_payload = JSON.parse(messages.find { |m| m[:role] == 'user' }[:content])
        expect(user_payload['prompt']).to eq('Retome o contato com o cliente de forma amigável.')
        expect(user_payload['prompt']).not_to include('Tom amigável')
        chat_result
      end

      service.perform!
    end

    it 'always includes last messages in context' do
      create(:message, conversation: conversation, account: account, inbox: inbox, content: 'Olá', message_type: :incoming)

      expect(PlatformAi::ChatClient).to receive(:complete) do |messages:, **|
        user_payload = JSON.parse(messages.find { |m| m[:role] == 'user' }[:content])
        contents = user_payload.dig('context', 'last_messages').pluck('content')
        expect(contents).to include('Olá')
        chat_result
      end

      service.perform!
    end

    it 'charges QuotaGuard after a successful completion' do
      expect(PlatformAi::QuotaGuard).to receive(:charge!).with(account: account, credits: 1)

      service.perform!
    end

    context 'when quota is exceeded' do
      before do
        account.update!(ai_credit_limit: 1, ai_credits_used: 1)
      end

      it 'skips ChatClient and does not send a message' do
        expect(PlatformAi::ChatClient).not_to receive(:complete)
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('quota_exceeded')
        expect(conversation.messages.where(private: false)).to be_empty
      end
    end

    context 'when atendimento_ia_nativo is disabled' do
      before { account.disable_features!('atendimento_ia_nativo') }

      it 'enqueues the legacy inteligencia_artificial webhook' do
        allow(Workflows::AiWebhook).to receive(:url).and_return('https://ia.example/hook')
        expect(WebhookJob).to receive(:perform_later).with(
          'https://ia.example/hook',
          hash_including(event: 'workflow.ai_outreach')
        )

        result = service.perform!

        expect(result[:success]).to be true
        expect(PlatformAi::ChatClient).not_to have_received(:complete)
      end
    end

    context 'when feature is disabled' do
      before { account.disable_features!('inteligencia_artificial') }

      it 'returns feature_disabled without calling ChatClient' do
        expect(PlatformAi::ChatClient).not_to receive(:complete)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('feature_disabled')
      end
    end
  end
end
