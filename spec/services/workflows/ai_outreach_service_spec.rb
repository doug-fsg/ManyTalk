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
    it 'enqueues webhook with workflow.ai_outreach event and composed prompt' do
      expect(WebhookJob).to receive(:perform_later).with(
        ai_url,
        hash_including(
          event: 'workflow.ai_outreach',
          prompt: include('Tom amigável e próximo.', 'cliente'),
          workflow_id: workflow.id,
          workflow_node_id: 'ai_1',
          enrollment_id: enrollment.id,
          ai_config: hash_including(
            objective_preset: 'reengagement',
            tone_preset: 'friendly',
            language: 'client',
            include_last_messages: true
          )
        )
      )

      result = service.perform!
      expect(result[:success]).to be true
    end

    it 'sends only interpolated prompt when prompt_customized is true' do
      node['data']['prompt_customized'] = true

      expect(WebhookJob).to receive(:perform_later) do |_url, payload|
        expect(payload[:prompt]).to eq('Retome o contato com o cliente de forma amigável.')
        expect(payload[:prompt]).not_to include('Tom amigável')
      end

      service.perform!
    end

    it 'always includes last messages in context' do
      create(:message, conversation: conversation, account: account, inbox: inbox, content: 'Olá', message_type: :incoming)

      expect(WebhookJob).to receive(:perform_later) do |_url, payload|
        contents = payload[:context][:last_messages].pluck(:content)
        expect(contents).to include('Olá')
      end

      service.perform!
    end

    context 'when WORKFLOW_AI_URL is missing' do
      let(:ai_url) { nil }

      it 'records webhook_url_missing without enqueueing webhook' do
        expect(WebhookJob).not_to receive(:perform_later)

        result = service.perform!
        expect(result[:success]).to be false
        expect(result[:error]).to eq('webhook_url_missing')
      end
    end
  end
end
