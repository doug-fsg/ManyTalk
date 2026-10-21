# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::CampaignDeliveryWait do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, conversation: conversation, message_type: :outgoing, status: :sent) }
  let(:sleeper) { class_double(Kernel) }

  before do
    allow(sleeper).to receive(:sleep)
  end

  it 'returns sent when source_id is already present' do
    message.update!(source_id: 'wamid.abc')

    result = described_class.new(message, timeout_seconds: 2, poll_seconds: 0.1, sleeper: sleeper).call

    expect(result).to be_sent
    expect(sleeper).not_to have_received(:sleep)
  end

  it 'returns failed when message is marked failed' do
    message.update!(status: :failed, external_error: '131000: Something went wrong')

    result = described_class.new(message, timeout_seconds: 2, poll_seconds: 0.1, sleeper: sleeper).call

    expect(result).to be_failed
  end

  it 'polls until source_id appears' do
    call_count = 0
    allow(message).to receive(:reload) do
      call_count += 1
      message.source_id = 'wamid.late' if call_count >= 3
      message
    end

    result = described_class.new(message, timeout_seconds: 5, poll_seconds: 0.01, sleeper: sleeper).call

    expect(result).to be_sent
    expect(sleeper).to have_received(:sleep).at_least(:once)
  end

  it 'returns timeout when neither source_id nor failed within deadline' do
    result = described_class.new(message, timeout_seconds: 0.05, poll_seconds: 0.01, sleeper: sleeper).call

    expect(result).to be_timeout
  end
end
