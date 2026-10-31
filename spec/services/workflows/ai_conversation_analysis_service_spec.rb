# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::AiConversationAnalysisService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Maria Silva') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
  end
  let(:workflow) { create(:workflow, account: account) }
  let(:enrollment) do
    create(:workflow_enrollment, workflow: workflow, conversation: conversation, account: account,
                                 current_node_id: 'analysis_1')
  end
  let(:node) do
    {
      'id' => 'analysis_1',
      'type' => 'ai_conversation_analysis',
      'data' => {
        'analysis_types' => %w[executive_summary service_quality],
        'output_destination' => 'private_note',
        'note_prefix' => 'Análise IA',
        'language' => 'pt_BR'
      }
    }
  end
  let(:analysis_json) do
    {
      'executive_summary' => 'Cliente pediu ajuda.',
      'service_quality' => 'Ainda sem resposta do atendente.'
    }.to_json
  end
  let(:chat_result) { { content: analysis_json, tool_calls: nil, total_tokens: 2000 } }

  subject(:service) do
    described_class.new(
      workflow: workflow,
      enrollment: enrollment,
      conversation: conversation,
      node: node
    )
  end

  before do
    account.enable_features!('inteligencia_artificial')
    allow(PlatformAi::ChatClient).to receive(:complete).and_return(chat_result)
    allow(PlatformAi::QuotaGuard).to receive(:charge!)
  end

  describe '#perform!' do
    it 'does not enqueue WORKFLOW_AI_URL webhook' do
      expect(WebhookJob).not_to receive(:perform_later)
      expect(Workflows::AiWebhook).not_to receive(:url)

      result = service.perform!
      expect(result[:success]).to be true
    end

    it 'writes a private note from JSON analysis' do
      expect { service.perform! }.to change { conversation.messages.where(private: true).count }.by(1)
      note = conversation.messages.where(private: true).last
      expect(note.content).to include('Análise IA')
      expect(note.content).to include('Cliente pediu ajuda.')
      expect(note.content).to include('Ainda sem resposta do atendente.')
    end

    it 'calls ChatClient with analysis types and conversation messages' do
      create(:message, conversation: conversation, account: account, inbox: inbox,
                       content: 'Preciso de ajuda', message_type: :incoming)

      expect(PlatformAi::ChatClient).to receive(:complete) do |messages:, **|
        user_payload = JSON.parse(messages.find { |m| m[:role] == 'user' }[:content])
        expect(user_payload['event']).to eq('workflow.ai_conversation_analysis')
        expect(user_payload['analysis_types']).to eq(%w[executive_summary service_quality])
        expect(user_payload['output']).to include('destination' => 'private_note')
        expect(user_payload['workflow_id']).to eq(workflow.id)
        expect(user_payload['workflow_node_id']).to eq('analysis_1')
        expect(user_payload['enrollment_id']).to eq(enrollment.id)
        expect(user_payload.dig('ai_config', 'locale')).to eq('pt_BR')
        msgs = user_payload.dig('context', 'messages')
        expect(msgs.first['content']).to eq('Preciso de ajuda')
        expect(msgs.first['message_type']).to eq('incoming')
        chat_result
      end

      service.perform!
    end

    it 'defaults to all analysis types when none are specified' do
      node['data'].delete('analysis_types')

      expect(PlatformAi::ChatClient).to receive(:complete) do |messages:, **|
        user_payload = JSON.parse(messages.find { |m| m[:role] == 'user' }[:content])
        expect(user_payload['analysis_types']).to match_array(Workflows::Constants::AI_ANALYSIS_TYPES)
        chat_result
      end

      service.perform!
    end

    it 'filters out invalid analysis types' do
      node['data']['analysis_types'] = %w[executive_summary invalid_type]

      expect(PlatformAi::ChatClient).to receive(:complete) do |messages:, **|
        user_payload = JSON.parse(messages.find { |m| m[:role] == 'user' }[:content])
        expect(user_payload['analysis_types']).to eq(%w[executive_summary])
        chat_result
      end

      service.perform!
    end

    context 'when whatsapp_external destination' do
      let(:channel_api) do
        create(:channel_api, account: account, webhook_url: 'https://bridge.example/webhook',
                             additional_attributes: { 'source' => 'whatsapp_web' })
      end
      let(:inbox) { channel_api.inbox }

      before do
        node['data']['output_destination'] = 'whatsapp_external'
        node['data']['whatsapp_inbox_id'] = inbox.id
        node['data']['whatsapp_phone'] = '5511999999999'
      end

      it 'sends analysis text via ExternalWhatsappNotifier without ChatClient' do
        create(:message, conversation: conversation, account: account, inbox: inbox,
                         content: 'Preciso de ajuda', message_type: :incoming)

        notifier = instance_double(Workflows::ExternalWhatsappNotifier, send!: { success: true })
        expect(Workflows::ExternalWhatsappNotifier).to receive(:new).and_return(notifier)
        expect(PlatformAi::ChatClient).not_to receive(:complete)
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be true
        expect(result[:delivery]).to eq('whatsapp')
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

    context 'when quota is exceeded' do
      before { account.update!(ai_credit_limit: 5, ai_credits_used: 5) }

      it 'returns quota_exceeded without calling ChatClient' do
        expect(PlatformAi::ChatClient).not_to receive(:complete)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('quota_exceeded')
      end
    end
  end
end
