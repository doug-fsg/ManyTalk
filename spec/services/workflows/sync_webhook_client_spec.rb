# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::SyncWebhookClient do
  let(:url) { 'https://example.com/webhook/intent' }
  let(:payload) { { event: 'test', enrollment_id: 1 } }

  describe '.post_json' do
    context 'when server returns matched: true' do
      before do
        stub_request(:post, url)
          .to_return(status: 200, body: '{"matched":true}', headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns ok: true and matched: true' do
        result = described_class.post_json(url, payload)
        expect(result).to eq(ok: true, matched: true, raw: { 'matched' => true })
      end
    end

    context 'when server returns matched: false' do
      before do
        stub_request(:post, url)
          .to_return(status: 200, body: '{"matched":false}')
      end

      it 'returns ok: true and matched: false' do
        result = described_class.post_json(url, payload)
        expect(result[:ok]).to be true
        expect(result[:matched]).to be false
      end
    end

    context 'when server times out' do
      before do
        stub_request(:post, url).to_timeout
      end

      it 'returns ok: false with error: :timeout and matched: false' do
        result = described_class.post_json(url, payload, timeout: 1)
        expect(result).to eq(ok: false, matched: false, error: :timeout)
      end
    end

    context 'when server returns HTTP 500' do
      before do
        stub_request(:post, url).to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns ok: false with error: :http_error' do
        result = described_class.post_json(url, payload)
        expect(result[:ok]).to be false
        expect(result[:matched]).to be false
        expect(result[:error]).to eq(:http_error)
      end
    end

    context 'when server returns invalid JSON' do
      before do
        stub_request(:post, url).to_return(status: 200, body: 'not json')
      end

      it 'returns ok: false with error: :invalid_json' do
        result = described_class.post_json(url, payload)
        expect(result[:ok]).to be false
        expect(result[:matched]).to be false
        expect(result[:error]).to eq(:invalid_json)
      end
    end

    context 'when matched field is absent' do
      before do
        stub_request(:post, url).to_return(status: 200, body: '{"confidence":0.9}')
      end

      it 'treats absent matched as false' do
        result = described_class.post_json(url, payload)
        expect(result[:matched]).to be false
      end
    end
  end
end
