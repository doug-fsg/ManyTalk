# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::AiConversationAnalysisService do
  let(:account) { create(:account) }
  let(:channel_api) do
    create(:channel_api, account: account, webhook_url: 'https://n8n.example.com/webhook/analysis',
                       additional_attributes: { 'source' => 'whatsapp_web' })
  end
  let(:inbox) { channel_api.inbox }
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

  subject(:service) do
    described_class.new(
      workflow: workflow,
      enrollment: enrollment,
      conversation: conversation,
      node: node
    )
  end

  before do
    allow(account).to receive(:feature_enabled?).with('inteligencia_artificial').and_return(true)
  end

  describe '#perform!' do
    it 'enqueues webhook with workflow.ai_conversation_analysis event' do
      expect(WebhookJob).to receive(:perform_later).with(
        'https://n8n.example.com/webhook/analysis',
        hash_including(
          event: 'workflow.ai_conversation_analysis',
          analysis_types: %w[executive_summary service_quality],
          output: hash_including(destination: 'private_note'),
          workflow_id: workflow.id,
          workflow_node_id: 'analysis_1',
          enrollment_id: enrollment.id
        ),
        :api_inbox_webhook
      )

      result = service.perform!
      expect(result[:success]).to be true
    end

    it 'includes conversation messages in context (capped at 100)' do
      create(:message, conversation: conversation, account: account, inbox: inbox,
                       content: 'Preciso de ajuda', message_type: :incoming)

      expect(WebhookJob).to receive(:perform_later) do |_url, payload, _type|
        msgs = payload[:context][:messages]
        expect(msgs).not_to be_empty
        expect(msgs.first[:content]).to eq('Preciso de ajuda')
        expect(msgs.first[:message_type]).to eq('incoming')
      end

      service.perform!
    end

    it 'defaults to all analysis types when none are specified' do
      node['data'].delete('analysis_types')

      expect(WebhookJob).to receive(:perform_later) do |_url, payload, _type|
        expect(payload[:analysis_types]).to match_array(Workflows::Constants::AI_ANALYSIS_TYPES)
      end

      service.perform!
    end

    it 'filters out invalid analysis types' do
      node['data']['analysis_types'] = %w[executive_summary invalid_type]

      expect(WebhookJob).to receive(:perform_later) do |_url, payload, _type|
        expect(payload[:analysis_types]).to eq(%w[executive_summary])
      end

      service.perform!
    end

    context 'when whatsapp_external destination' do
      before do
        node['data']['output_destination'] = 'whatsapp_external'
        node['data']['whatsapp_inbox_id'] = inbox.id
        node['data']['whatsapp_phone'] = '5511999999999'
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('WEBHOOK_URL', nil).and_return('https://bridge.example/webhook')
        allow(ENV).to receive(:fetch).with('WEBHOOKS_TRIGGER_TIMEOUT', '15').to_i).and_return(5)
      end

      it 'sends analysis text via ExternalWhatsappNotifier without analysis webhook' do
        create(:message, conversation: conversation, account: account, inbox: inbox,
                         content: 'Preciso de ajuda', message_type: :incoming)

        response = instance_double(RestClient::Response, code: 200, body: 'ok')
        expect(RestClient::Request).to receive(:execute).and_return(response)
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be true
        expect(result[:delivery]).to eq('webhook')
      end
    end

    context 'when feature is disabled' do
      before do
        allow(account).to receive(:feature_enabled?).with('inteligencia_artificial').and_return(false)
      end

      it 'returns feature_disabled without enqueueing webhook' do
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('feature_disabled')
      end
    end

    context 'when inbox is not API' do
      let(:email_inbox) { create(:inbox, account: account) }
      let(:conversation) do
        create(:conversation, account: account, inbox: email_inbox, contact: contact)
      end

      it 'returns inbox_not_supported without enqueueing webhook' do
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('inbox_not_supported')
      end
    end

    context 'when webhook_url is missing' do
      before { channel_api.update!(webhook_url: nil) }

      it 'returns webhook_url_missing without enqueueing webhook' do
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('webhook_url_missing')
      end
    end
  end
end
