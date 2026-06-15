require 'rails_helper'

RSpec.describe EventDispatcherJob do
  subject(:job) { described_class.perform_later(event_name, timestamp, serialized_data) }

  let!(:conversation) { create(:conversation) }
  let(:event_name) { 'conversation.created' }
  let(:timestamp) { Time.zone.now }
  let(:event_data) { { conversation: conversation } }
  let(:serialized_data) { Events::PayloadSerializer.dump(event_data) }

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(event_name, timestamp, serialized_data)
      .on_queue('critical')
  end

  it 'publishes event' do
    expect(Rails.configuration.dispatcher.async_dispatcher).to receive(:publish_event).with(event_name, timestamp, event_data).once
    event_dispatcher = described_class.new
    event_dispatcher.perform(event_name, timestamp, serialized_data)
  end

  it 'skips publish when the primary record was deleted' do
    payload = { 'conversation' => { '__ar__' => 'Conversation', 'id' => -1 } }
    expect(Rails.configuration.dispatcher.async_dispatcher).not_to receive(:publish_event)

    described_class.new.perform(Events::Types::CONVERSATION_CREATED, timestamp, payload)
  end
end
