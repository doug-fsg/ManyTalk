# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contacts::BackfillPipelineEventsJob, type: :job do
  it 'creates entered and won events for legacy positions without history' do
    contact = create(:contact, :with_email)
    position = create(:contact_pipeline_position, contact: contact)
    ContactPipelineEvent.delete_all
    position.update_columns(
      metadata: {
        'win_lost' => {
          'status' => 'won',
          'date' => 1.day.ago.iso8601,
          'notes' => 'Backfilled win'
        }
      }
    )

    described_class.perform_now

    expect(
      ContactPipelineEvent.where(contact_pipeline_position: position, event_type: 'entered').count
    ).to eq(1)
    expect(
      ContactPipelineEvent.where(contact_pipeline_position: position, event_type: 'won').count
    ).to eq(1)
  end
end
