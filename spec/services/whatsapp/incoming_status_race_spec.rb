# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WhatsApp status webhook race' do
  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { whatsapp_channel.inbox }

  def cloud_status_params(status_id:, status:)
    {
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          value: {
            metadata: {
              phone_number_id: whatsapp_channel.provider_config['phone_number_id'],
              display_phone_number: whatsapp_channel.phone_number.delete('+')
            },
            statuses: [{
              id: status_id,
              status: status,
              timestamp: Time.now.to_i.to_s,
              recipient_id: '5511999999999'
            }]
          }
        }]
      }]
    }.with_indifferent_access
  end

  it 'enqueues ApplyStatusUpdateJob when message source_id is not yet persisted' do
    params = cloud_status_params(status_id: 'wamid.not-yet-in-db', status: 'delivered')

    expect do
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: params).perform
    end.to have_enqueued_job(Whatsapp::ApplyStatusUpdateJob)
  end

  it 'updates immediately when message already has source_id' do
    conversation = create(:conversation, inbox: inbox)
    message = create(:message, conversation: conversation, message_type: :outgoing, source_id: 'wamid.ready', status: :sent)
    params = cloud_status_params(status_id: 'wamid.ready', status: 'read')

    expect do
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: params).perform
    end.not_to have_enqueued_job(Whatsapp::ApplyStatusUpdateJob)

    expect(message.reload.status).to eq('read')
  end
end
