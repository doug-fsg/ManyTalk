require 'rails_helper'

RSpec.describe Webhooks::WhatsappEventsJob, type: :job do
  describe 'coexistence routing' do
    let(:channel) do
      create(
        :channel_whatsapp,
        provider: 'whatsapp_cloud',
        sync_templates: false,
        validate_provider_config: false
      )
    end
    let(:echo_params) do
      {
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            field: 'smb_message_echoes',
            value: {
              message_echoes: [{
                from: channel.phone_number.delete('+'),
                to: '5511888888888',
                id: 'wamid.echo456',
                type: 'text',
                text: { body: 'Echo test' }
              }]
            }
          }]
        }]
      }.with_indifferent_access
    end

    before do
      allow_any_instance_of(described_class).to receive(:with_lock).and_yield
    end

    it 'routes smb_message_echoes to IncomingMessageEchoService' do
      echo_service = instance_double(Whatsapp::IncomingMessageEchoService, perform: true)
      allow(Whatsapp::IncomingMessageEchoService).to receive(:new).and_return(echo_service)

      described_class.perform_now(echo_params)

      expect(Whatsapp::IncomingMessageEchoService).to have_received(:new).with(
        inbox: channel.inbox,
        params: echo_params
      )
      expect(echo_service).to have_received(:perform)
    end

    it 'resolves channel from echo from number when metadata is missing' do
      echo_service = instance_double(Whatsapp::IncomingMessageEchoService, perform: true)
      allow(Whatsapp::IncomingMessageEchoService).to receive(:new).and_return(echo_service)

      described_class.perform_now(echo_params)

      expect(Whatsapp::IncomingMessageEchoService).to have_received(:new)
    end
  end
end
