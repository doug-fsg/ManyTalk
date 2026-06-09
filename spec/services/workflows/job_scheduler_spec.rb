# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::JobScheduler do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:workflow) { create(:workflow, account: account) }
  let(:enrollment) do
    create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
  end

  before do
    account.enable_features!('workflows')
    clear_enqueued_jobs
  end

  describe '.schedule' do
    it 'enqueues a StepJob with the given delay' do
      expect {
        described_class.schedule(enrollment, 'wait_1', 6.hours)
      }.to have_enqueued_job(Workflows::StepJob)
    end

    it 'creates a step execution record' do
      described_class.schedule(enrollment, 'wait_1', 6.hours)
      execution = enrollment.workflow_step_executions.find_by(node_id: 'wait_1')
      expect(execution).to be_present
      expect(execution.status).to eq('scheduled')
    end

    it 'sets scheduled_at based on current time plus delay' do
      freeze_time do
        described_class.schedule(enrollment, 'wait_1', 6.hours)
        execution = enrollment.workflow_step_executions.find_by(node_id: 'wait_1')
        expect(execution.scheduled_at).to eq(6.hours.from_now)
      end
    end

    it 'stores the Sidekiq job_id on the execution' do
      described_class.schedule(enrollment, 'wait_1', 6.hours)
      execution = enrollment.workflow_step_executions.find_by(node_id: 'wait_1')
      expect(execution.job_id).to be_present
    end

    it 'updates an existing execution for the same node_id' do
      described_class.schedule(enrollment, 'wait_1', 6.hours)
      expect {
        described_class.schedule(enrollment, 'wait_1', 3.hours)
      }.not_to change(WorkflowStepExecution, :count)

      execution = enrollment.workflow_step_executions.find_by(node_id: 'wait_1')
      expect(execution.scheduled_at).to be_within(1.minute).of(3.hours.from_now)
    end
  end

  describe '.cancel_pending!' do
    it 'does not raise even with non-existent Sidekiq job' do
      create(:workflow_step_execution, workflow_enrollment: enrollment, node_id: 'wait_1', status: 'scheduled', job_id: 'fake-123')
      expect { described_class.cancel_pending!(enrollment) }.not_to raise_error
    end

    it 'only processes scheduled executions' do
      completed = create(:workflow_step_execution, workflow_enrollment: enrollment, node_id: 'action_1', status: 'completed')
      expect { described_class.cancel_pending!(enrollment) }.not_to raise_error
      expect(completed.reload.status).to eq('completed')
    end
  end

  describe '.remaining_delay' do
    it 'returns the remaining time until scheduled_at' do
      freeze_time do
        execution = build(:workflow_step_execution, scheduled_at: 2.hours.from_now)
        delay = described_class.remaining_delay(execution)
        expect(delay).to be_within(1.second).of(2.hours)
      end
    end

    it 'returns at least 1 second for past scheduled times' do
      execution = build(:workflow_step_execution, scheduled_at: 1.hour.ago)
      delay = described_class.remaining_delay(execution)
      expect(delay).to eq(1.second)
    end

    it 'returns 0 seconds for nil execution' do
      expect(described_class.remaining_delay(nil)).to eq(0.seconds)
    end

    it 'returns 0 seconds when scheduled_at is nil' do
      execution = build(:workflow_step_execution, scheduled_at: nil)
      expect(described_class.remaining_delay(execution)).to eq(0.seconds)
    end
  end
end
