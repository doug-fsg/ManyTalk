# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ActivationService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:workflow) { create(:workflow, account: account, active: true) }
  let!(:enrollment) do
    create(:workflow_enrollment, workflow: workflow, account: account, conversation: conversation, status: 'waiting',
                                 current_node_id: 'action_1')
  end

  before do
    account.enable_features!('workflows')
    allow(Workflows::EnrollmentBroadcaster).to receive(:updated)
    allow(Workflows::JobScheduler).to receive(:cancel_pending!)
    allow(Workflows::JobScheduler).to receive(:schedule)
    allow(Workflows::OrchestratorService).to receive(:advance_from_node)
  end

  it 'pauses in-progress enrollments when the workflow is deactivated' do
    described_class.new.pause_in_progress!(workflow)
    expect(enrollment.reload.status).to eq('paused')
    expect(enrollment.pause_reason).to eq('workflow_inactive')
  end

  it 'resumes enrollments paused because the workflow was inactive' do
    described_class.new.pause_in_progress!(workflow)
    described_class.new.resume_inactive!(workflow)
    expect(enrollment.reload.status).to eq('active')
    expect(enrollment.pause_reason).to be_nil
  end

  it 'does not resume enrollments paused for other reasons' do
    enrollment.pause!(reason: 'manual')
    described_class.new.resume_inactive!(workflow)
    expect(enrollment.reload.status).to eq('paused')
    expect(enrollment.pause_reason).to eq('manual')
  end
end
