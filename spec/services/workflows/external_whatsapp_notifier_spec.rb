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
      allow(ENV).to receive(:fetch).with('WEBHOOKS_TRIGGER_TIMEOUT', '15').to_i).and_return(5)
    end

    it 'posts synchronously to WEBHOOK_URL without creating a conversation' do
      response = instance_double(RestClient::Response, code: 200, body: 'ok')
      expect(RestClient::Request).to receive(:execute).with(
        hash_including(
          method: :post,
          url: 'https://bridge.example/webhook',
          payload: a_string_including('"event":"workflow.external_whatsapp"')
        )
      ).and_return(response)

      result = described_class.new(
        account: account,
        inbox_id: inbox.id,
        phone_number: '11999999999',
        message: 'Aviso do fluxo'
      ).send!

      expect(result[:success]).to be true
      expect(result[:delivery]).to eq('webhook')
      expect(Conversation.count).to eq(0)
    end

    it 'returns webhook_url_missing when no bridge url is configured' do
      allow(ENV).to receive(:fetch).with('WEBHOOK_URL', nil).and_return(nil)
      channel.update!(webhook_url: nil)

      result = described_class.new(
        account: account,
        inbox_id: inbox.id,
        phone_number: '11999999999',
        message: 'Aviso'
      ).send!

      expect(result[:success]).to be false
      expect(result[:error]).to eq('webhook_url_missing')
    end

    it 'returns webhook_failed when bridge responds with error' do
      error = RestClient::ExceptionWithResponse.new
      allow(error).to receive(:response).and_return(instance_double(RestClient::Response, body: 'bad gateway'))
      allow(RestClient::Request).to receive(:execute).and_raise(error)

      result = described_class.new(
        account: account,
        inbox_id: inbox.id,
        phone_number: '11999999999',
        message: 'Aviso'
      ).send!

      expect(result[:success]).to be false
      expect(result[:error]).to eq('webhook_failed')
    end
  end
end
