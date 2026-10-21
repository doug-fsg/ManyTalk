# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::ApplyStatusUpdateJob do
  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  let(:channel) { create(:channel_whatsapp, sync_templates: false, validate_provider_config: false) }
  let(:conversation) { create(:conversation, inbox: channel.inbox) }

  it 'updates message status when source_id exists' do
    message = create(:message, conversation: conversation, message_type: :outgoing, source_id: 'wamid.status1', status: :sent)

    described_class.perform_now(
      source_id: 'wamid.status1',
      status_payload: { 'id' => 'wamid.status1', 'status' => 'delivered' },
      inbox_id: channel.inbox.id
    )

    expect(message.reload.status).to eq('delivered')
  end

  it 'sets external_error on failed status' do
    message = create(:message, conversation: conversation, message_type: :outgoing, source_id: 'wamid.status2', status: :sent)

    described_class.perform_now(
      source_id: 'wamid.status2',
      status_payload: {
        'id' => 'wamid.status2',
        'status' => 'failed',
        'errors' => [{ 'code' => 131_049, 'title' => 'Marketing limit' }]
      },
      inbox_id: channel.inbox.id
    )

    expect(message.reload.status).to eq('failed')
    expect(message.external_error).to be_present
  end

  it 'raises RecordNotFound when message is missing so ActiveJob can retry' do
    # Call #perform on the instance to assert the raise without executing retry_on waits.
    expect do
      described_class.new.perform(
        source_id: 'wamid.missing',
        status_payload: { 'id' => 'wamid.missing', 'status' => 'delivered' },
        inbox_id: channel.inbox.id
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
