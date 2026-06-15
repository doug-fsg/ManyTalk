# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ExternalWhatsappNotifier do
  let(:account) { create(:account) }

  describe 'WhatsApp Web (API) inbox' do
    let(:channel) do
      create(:channel_api, account: account, additional_attributes: { 'source' => 'whatsapp_web' })
    end
    let(:inbox) { channel.inbox }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('WEBHOOK_URL', nil).and_return('https://bridge.example/webhook')
    end

    it 'enqueues webhook without creating a conversation' do
      expect do
        result = described_class.new(
          account: account,
          inbox_id: inbox.id,
          phone_number: '11999999999',
          message: 'Aviso do fluxo'
        ).send!

        expect(result[:success]).to be true
        expect(result[:delivery]).to eq('webhook')
      end.to have_enqueued_job(WebhookJob).with(
        'https://bridge.example/webhook',
        hash_including(
          event: 'workflow.external_whatsapp',
          content: 'Aviso do fluxo',
          phone_number: '+5511999999999',
          notification_only: true
        ),
        :api_inbox_webhook
      )

      expect(Conversation.count).to eq(0)
    end

    it 'returns webhook_url_missing when no bridge url is configured' do
      allow(ENV).to receive(:fetch).with('WEBHOOK_URL', nil).and_return(nil)

      result = described_class.new(
        account: account,
        inbox_id: inbox.id,
        phone_number: '11999999999',
        message: 'Aviso'
      ).send!

      expect(result[:success]).to be false
      expect(result[:error]).to eq('webhook_url_missing')
    end
  end
end
