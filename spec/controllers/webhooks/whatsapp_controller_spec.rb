require 'rails_helper'

RSpec.describe 'Webhooks::WhatsappController', type: :request do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:client_secret) { 'test-whatsapp-secret' }
  let(:body) { { content: 'hello' }.to_json }

  def signature_for(body, secret = client_secret)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, body)}"
  end

  def post_whatsapp_webhook(path, body, signature: signature_for(body), env: {})
    with_modified_env({ WHATSAPP_WEBHOOK_SIGNATURE_ENFORCE: 'true', WHATSAPP_APP_SECRET: client_secret }.merge(env)) do
      post path,
           params: body,
           headers: { 'CONTENT_TYPE' => 'application/json', 'X-Hub-Signature-256' => signature }
    end
  end

  def post_unsigned_whatsapp_webhook(path, body, env: {})
    with_modified_env({ WHATSAPP_WEBHOOK_SIGNATURE_ENFORCE: 'true', WHATSAPP_APP_SECRET: client_secret }.merge(env)) do
      post path,
           params: body,
           headers: { 'CONTENT_TYPE' => 'application/json' }
    end
  end

  before do
    InstallationConfig.where(name: 'WHATSAPP_APP_SECRET').delete_all
    InstallationConfig.where(name: 'WHATSAPP_WEBHOOK_SIGNATURE_ENFORCE').delete_all
    GlobalConfig.clear_cache
  end

  describe 'GET /webhooks/verify' do
    it 'returns 401 when valid params are not present' do
      get "/webhooks/whatsapp/#{channel.phone_number}"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 when invalid params' do
      get "/webhooks/whatsapp/#{channel.phone_number}",
          params: { 'hub.challenge' => '123456', 'hub.mode' => 'subscribe', 'hub.verify_token' => 'invalid' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns challenge when valid params' do
      get "/webhooks/whatsapp/#{channel.phone_number}",
          params: { 'hub.challenge' => '123456', 'hub.mode' => 'subscribe', 'hub.verify_token' => channel.provider_config['webhook_verify_token'] }
      expect(response.body).to include '123456'
    end
  end

  describe 'POST /webhooks/whatsapp/{:phone_number}' do
    context 'when signature enforce is off (production default)' do
      it 'accepts unsigned payloads so existing Meta subscriptions keep working' do
        allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
        with_modified_env WHATSAPP_WEBHOOK_SIGNATURE_ENFORCE: 'false' do
          post '/webhooks/whatsapp/123221321', params: { content: 'hello' }
        end
        expect(response).to have_http_status(:success)
        expect(Webhooks::WhatsappEventsJob).to have_received(:perform_later)
      end
    end

    context 'with WhatsApp Business payloads and enforce on' do
      let(:tracking_change) do
        { field: 'tracking_events', value: { events: [{ event_name: 'delivered', timestamp: 1_788_091_821 }] } }
      end
      let(:entries) { [{ changes: [tracking_change] }] }
      let(:payload) { { object: 'whatsapp_business_account', entry: entries } }
      let(:body) { payload.to_json }

      before do
        allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      end

      it 'acknowledges tracking-only payloads without enqueueing a job' do
        post_whatsapp_webhook('/webhooks/whatsapp/123221321', body)

        expect(response).to have_http_status(:ok)
        expect(Webhooks::WhatsappEventsJob).not_to have_received(:perform_later)
      end

      it 'rejects tracking-only payloads for inactive numbers' do
        allow(GlobalConfig).to receive(:get_value).with('INACTIVE_WHATSAPP_NUMBERS').and_return('+1234567890')

        post_whatsapp_webhook('/webhooks/whatsapp/+1234567890', body)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Inactive WhatsApp number')
        expect(Webhooks::WhatsappEventsJob).not_to have_received(:perform_later)
      end

      it 'rejects unsigned tracking-only payloads when enforce is on' do
        post_unsigned_whatsapp_webhook('/webhooks/whatsapp/123221321', body)

        expect(response).to have_http_status(:unauthorized)
        expect(Webhooks::WhatsappEventsJob).not_to have_received(:perform_later)
      end

      it 'rejects tracking-only payloads with an invalid signature' do
        post_whatsapp_webhook('/webhooks/whatsapp/123221321', body, signature: 'sha256=invalid-signature')

        expect(response).to have_http_status(:unauthorized)
        expect(Webhooks::WhatsappEventsJob).not_to have_received(:perform_later)
      end

      %w[sent delivered read failed].each do |status|
        it "enqueues ordinary #{status} message-status updates" do
          payload[:entry] = [{ changes: [{ field: 'messages', value: { statuses: [{ id: 'wamid.test', status: status }] } }] }]
          post_whatsapp_webhook('/webhooks/whatsapp/123221321', payload.to_json)

          expect(response).to have_http_status(:ok)
          expect(Webhooks::WhatsappEventsJob).to have_received(:perform_later)
        end
      end
    end

    it 'calls the whatsapp events job with the params for a valid signature' do
      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      expect(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      post_whatsapp_webhook('/webhooks/whatsapp/123221321', body)
      expect(response).to have_http_status(:success)
    end

    it 'accepts webhook payloads signed with the channel app secret' do
      channel_secret = 'channel-whatsapp-secret'
      channel.provider_config = channel.provider_config.merge('app_secret' => channel_secret)
      channel.save!(validate: false)

      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      expect(Webhooks::WhatsappEventsJob).to receive(:perform_later)

      channel_body = {
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            value: {
              metadata: {
                display_phone_number: channel.phone_number.delete_prefix('+'),
                phone_number_id: channel.provider_config['phone_number_id']
              }
            }
          }]
        }]
      }.to_json

      post_whatsapp_webhook(
        "/webhooks/whatsapp/#{channel.phone_number}",
        channel_body,
        signature: signature_for(channel_body, channel_secret),
        env: { WHATSAPP_APP_SECRET: '' }
      )

      expect(response).to have_http_status(:success)
    end

    it 'skips signature validation for 360dialog channels even when enforce is on' do
      dialog_channel = create(:channel_whatsapp, provider: 'default', sync_templates: false, validate_provider_config: false)
      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      expect(Webhooks::WhatsappEventsJob).to receive(:perform_later)

      post_unsigned_whatsapp_webhook("/webhooks/whatsapp/#{dialog_channel.phone_number}", body)

      expect(response).to have_http_status(:success)
    end

    it 'returns unauthorized when signature is missing and enforce is on' do
      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)

      post_unsigned_whatsapp_webhook('/webhooks/whatsapp/123221321', body)

      expect(response).to have_http_status(:unauthorized)
      expect(Webhooks::WhatsappEventsJob).not_to have_received(:perform_later)
    end

    context 'when phone number is in inactive list' do
      before do
        allow(GlobalConfig).to receive(:get_value).with('INACTIVE_WHATSAPP_NUMBERS').and_return('+1234567890,+9876543210')
      end

      it 'returns unprocessable entity for inactive phone number in URL params' do
        allow(Rails.logger).to receive(:warn)
        expect(Rails.logger).to receive(:warn).with('Rejected webhook for inactive WhatsApp number: +1234567890')

        post_whatsapp_webhook('/webhooks/whatsapp/+1234567890', body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Inactive WhatsApp number')
      end
    end
  end
end
