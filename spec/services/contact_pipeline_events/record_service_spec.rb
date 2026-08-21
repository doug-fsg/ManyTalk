# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactPipelineEvents::RecordService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:contact) { create(:contact, :with_email, account: account) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }

  before do
    Current.user = user
  end

  after do
    Current.user = nil
  end

  it 'records entered event when position is created' do
    position = create(
      :contact_pipeline_position,
      contact: contact,
      pipeline: pipeline,
      stage_id: 'Proposta'
    )

    event = ContactPipelineEvent.find_by(contact_pipeline_position: position, event_type: 'entered')
    expect(event).to be_present
    expect(event.to_stage_id).to eq('Proposta')
    expect(event.user_id).to eq(user.id)
  end

  it 'records stage_changed event when stage updates' do
    position = create(
      :contact_pipeline_position,
      contact: contact,
      pipeline: pipeline,
      stage_id: 'Proposta'
    )

    position.update!(stage_id: 'Negociação', entered_at: Time.current)

    event = ContactPipelineEvent.where(contact_pipeline_position: position, event_type: 'stage_changed').last
    expect(event).to be_present
    expect(event.from_stage_id).to eq('Proposta')
    expect(event.to_stage_id).to eq('Negociação')
  end

  it 'records won event when win_lost metadata is set' do
    position = create(
      :contact_pipeline_position,
      contact: contact,
      pipeline: pipeline,
      stage_id: 'Fechado'
    )

    position.update!(
      metadata: {
        'win_lost' => {
          'status' => 'won',
          'date' => Time.current.iso8601,
          'notes' => 'Assinou contrato'
        }
      },
      deal_value: 2500
    )

    event = ContactPipelineEvent.find_by(contact_pipeline_position: position, event_type: 'won')
    expect(event).to be_present
    expect(event.metadata['win_lost_notes']).to eq('Assinou contrato')
  end

  it 'records win_lost_cleared when win_lost metadata is removed' do
    position = create(
      :contact_pipeline_position,
      contact: contact,
      pipeline: pipeline,
      metadata: {
        'win_lost' => { 'status' => 'won', 'date' => Time.current.iso8601 }
      }
    )

    position.update!(metadata: {})

    event = ContactPipelineEvent.find_by(contact_pipeline_position: position, event_type: 'win_lost_cleared')
    expect(event).to be_present
    expect(event.metadata['previous_status']).to eq('won')
  end

  it 'stores workflow metadata when executed by a workflow' do
    Current.user = nil
    workflow = create(:workflow, account: account, name: 'Follow-up 24h')
    Current.executed_by = workflow

    position = create(
      :contact_pipeline_position,
      contact: contact,
      pipeline: pipeline,
      stage_id: 'Proposta'
    )

    event = ContactPipelineEvent.find_by(contact_pipeline_position: position, event_type: 'entered')
    expect(event.user_id).to be_nil
    expect(event.metadata['source']).to eq('workflow')
    expect(event.metadata['workflow_id']).to eq(workflow.id)
    expect(event.metadata['workflow_name']).to eq('Follow-up 24h')
  ensure
    Current.executed_by = nil
  end
end
