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
  let(:ai_url) { 'https://n8n.example.com/webhook/ai' }

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
    allow(Workflows::AiWebhook).to receive(:url).and_return(ai_url)
  end

  describe '#perform!' do
    it 'enqueues webhook with workflow.ai_conversation_analysis event' do
      expect(WebhookJob).to receive(:perform_later).with(
        ai_url,
        hash_including(
          event: 'workflow.ai_conversation_analysis',
          analysis_types: %w[executive_summary service_quality],
          output: hash_including(destination: 'private_note'),
          workflow_id: workflow.id,
          workflow_node_id: 'analysis_1',
          enrollment_id: enrollment.id
        )
      )

      result = service.perform!
      expect(result[:success]).to be true
    end

    it 'includes conversation messages in context (capped at 100)' do
      create(:message, conversation: conversation, account: account, inbox: inbox,
                       content: 'Preciso de ajuda', message_type: :incoming)

      expect(WebhookJob).to receive(:perform_later) do |_url, payload|
        msgs = payload[:context][:messages]
        expect(msgs).not_to be_empty
        expect(msgs.first[:content]).to eq('Preciso de ajuda')
        expect(msgs.first[:message_type]).to eq('incoming')
      end

      service.perform!
    end

    it 'defaults to all analysis types when none are specified' do
      node['data'].delete('analysis_types')

      expect(WebhookJob).to receive(:perform_later) do |_url, payload|
        expect(payload[:analysis_types]).to match_array(Workflows::Constants::AI_ANALYSIS_TYPES)
      end

      service.perform!
    end

    it 'filters out invalid analysis types' do
      node['data']['analysis_types'] = %w[executive_summary invalid_type]

      expect(WebhookJob).to receive(:perform_later) do |_url, payload|
        expect(payload[:analysis_types]).to eq(%w[executive_summary])
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

      it 'sends analysis text via ExternalWhatsappNotifier without analysis webhook' do
        create(:message, conversation: conversation, account: account, inbox: inbox,
                         content: 'Preciso de ajuda', message_type: :incoming)

        notifier = instance_double(Workflows::ExternalWhatsappNotifier, send!: { success: true })
        expect(Workflows::ExternalWhatsappNotifier).to receive(:new).and_return(notifier)
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be true
        expect(result[:delivery]).to eq('whatsapp')
      end
    end

    context 'when feature is disabled' do
      before { account.disable_features!('inteligencia_artificial') }

      it 'returns feature_disabled without enqueueing webhook' do
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('feature_disabled')
      end
    end

    context 'when WORKFLOW_AI_URL is missing' do
      let(:ai_url) { nil }

      it 'returns webhook_url_missing without enqueueing webhook' do
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('webhook_url_missing')
      end
    end
  end
end
