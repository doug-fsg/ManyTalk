# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::RunScheduleJob do
  let(:account) { create(:account) }
  let(:workflow) { create(:workflow, account: account, active: true) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }
  let(:schedule) do
    create(
      :workflow_schedule,
      account: account,
      workflow: workflow,
      pipeline: pipeline,
      active: true,
      run_token: 4,
      last_run_status: 'running'
    )
  end

  before { account.enable_features!('workflows') }

  it 'marks the run completed when the stage is empty' do
    described_class.perform_now(schedule.id, 4, 0)

    expect(schedule.reload.last_run_status).to eq('completed')
  end

  it 'enqueues a contact batch and the next page when there are more contacts than the batch size' do
    stub_const('Workflows::Constants::SCHEDULE_BATCH_SIZE', 1)
    first = create(:contact, account: account)
    second = create(:contact, account: account)
    create(:contact_pipeline_position, contact: first, pipeline: pipeline, stage_id: 'Estágio 1')
    create(:contact_pipeline_position, contact: second, pipeline: pipeline, stage_id: 'Estágio 1')

    expect do
      described_class.perform_now(schedule.id, 4, 0)
    end.to have_enqueued_job(Workflows::ScheduleEnrollBatchJob)
      .and have_enqueued_job(described_class)

    expect(schedule.reload.last_run_status).to eq('running')
  end

  it 'ignores a stale run_token' do
    expect do
      described_class.perform_now(schedule.id, 3, 0)
    end.not_to have_enqueued_job(Workflows::ScheduleEnrollBatchJob)

    expect(schedule.reload.last_run_status).to eq('running')
  end
end
