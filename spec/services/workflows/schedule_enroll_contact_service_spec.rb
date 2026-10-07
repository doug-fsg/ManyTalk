# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ScheduleEnrollContactService do
  let(:account) { create(:account) }
  let(:workflow) { create(:workflow, account: account, active: true) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }
  let(:schedule) do
    create(:workflow_schedule, account: account, workflow: workflow, pipeline: pipeline, stage_id: 'Estágio 1')
  end
  let(:contact) { create(:contact, :with_phone_number, account: account) }

  before { account.enable_features!('workflows') }

  def service_for(contact_id)
    described_class.new(schedule: schedule, contact_id: contact_id)
  end

  it 'skips when the contact left the stage' do
    expect(service_for(contact.id).perform).to eq(:left_stage)
  end

  it 'skips missing contacts' do
    expect(service_for(-1).perform).to eq(:missing)
  end

  it 'skips when no conversation can be resolved' do
    create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')

    expect(service_for(contact.id).perform).to eq(:no_conversation)
  end

  it 'enrolls an open conversation for a contact still on the stage' do
    inbox = create(:inbox, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')

    expect { service_for(contact.id).perform }.to change(WorkflowEnrollment, :count).by(1)
    enrollment = WorkflowEnrollment.last
    expect(enrollment.workflow).to eq(workflow)
    expect(enrollment.conversation).to eq(conversation)
  end

  it 'skips when enrollment is already blocked' do
    inbox = create(:inbox, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')
    create(:workflow_enrollment, workflow: workflow, conversation: conversation, account: account, contact: contact)

    expect(service_for(contact.id).perform).to eq(:skipped)
  end
end
