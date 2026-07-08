require 'rails_helper'

RSpec.describe Whatsapp::IncomingMessageEchoService do
  let(:account) { create(:account) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:inbox) { channel.inbox }
  let(:contact_phone) { '5511999999999' }
  let(:echo_id) { 'wamid.echo123' }
  let(:params) do
    {
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          field: 'smb_message_echoes',
          value: {
            metadata: {
              phone_number_id: channel.provider_config['phone_number_id'],
              display_phone_number: channel.phone_number.delete('+')
            },
            message_echoes: [{
              from: channel.phone_number.delete('+'),
              to: contact_phone,
              id: echo_id,
              timestamp: '1710000000',
              type: 'text',
              text: { body: 'Resposta pelo app Business' }
            }]
          }
        }]
      }]
    }.with_indifferent_access
  end

  before do
    account.enable_features!('whatsapp_coexistence')
    allow(Redis::Alfred).to receive(:set).and_return(true)
  end

  it 'creates outgoing message with external_echo and source_id' do
    expect do
      described_class.new(inbox: inbox, params: params).perform
    end.to change(Message, :count).by(1)

    message = Message.last
    expect(message.outgoing?).to be true
    expect(message.source_id).to eq(echo_id)
    expect(message.content_attributes['external_echo']).to be true
    expect(message.status).to eq('delivered')
    expect(message.content).to eq('Resposta pelo app Business')
  end

  it 'does not create duplicate messages for same echo id' do
    described_class.new(inbox: inbox, params: params).perform

    expect do
      described_class.new(inbox: inbox, params: params).perform
    end.not_to change(Message, :count)
  end

  it 'skips processing when feature flag is disabled' do
    account.disable_features!('whatsapp_coexistence')

    expect do
      described_class.new(inbox: inbox, params: params).perform
    end.not_to change(Message, :count)
  end
end
