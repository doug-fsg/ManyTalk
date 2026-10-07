# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::DueSchedulesTickJob do
  let(:account) { create(:account) }
  let(:workflow) { create(:workflow, account: account, active: true) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }

  before { account.enable_features!('workflows') }

  it 'enqueues a run job only for claimed due schedules' do
    due = create(
      :workflow_schedule,
      account: account,
      workflow: workflow,
      pipeline: pipeline,
      active: true,
      next_run_at: 1.minute.ago
    )
    create(
      :workflow_schedule,
      account: account,
      workflow: workflow,
      pipeline: pipeline,
      active: true,
      next_run_at: 2.hours.from_now
    )

    expect do
      described_class.perform_now
    end.to have_enqueued_job(Workflows::RunScheduleJob).once

    due.reload
    expect(due.last_run_status).to eq('running')
  end
end
