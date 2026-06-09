# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowEnrollment, type: :model do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:workflow) { create(:workflow, account: account) }

  before { account.enable_features!('workflows') }

  describe 'associations' do
    it { is_expected.to belong_to(:workflow) }
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:workflow_step_executions).dependent(:destroy_async) }
    it { is_expected.to belong_to(:paused_by).class_name('User').optional }
    it { is_expected.to belong_to(:started_by).class_name('User').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:status).in_array(WorkflowEnrollment::STATUSES) }
    it { is_expected.to validate_inclusion_of(:pause_reason).in_array(WorkflowEnrollment::Lifecycle::PAUSE_REASONS).allow_nil }
  end

  describe 'Lifecycle transitions' do
    describe '#pause!' do
      it 'transitions from active to paused' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        enrollment.pause!(reason: 'manual')
        expect(enrollment.reload.status).to eq('paused')
        expect(enrollment.paused_at).to be_present
        expect(enrollment.pause_reason).to eq('manual')
      end

      it 'transitions from waiting to paused' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'waiting')
        enrollment.pause!(reason: 'contact_replied')
        expect(enrollment.reload.status).to eq('paused')
      end

      it 'records the user who paused' do
        user = create(:user, account: account)
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        enrollment.pause!(user: user, reason: 'manual')
        expect(enrollment.reload.paused_by).to eq(user)
      end

      it 'raises when already paused' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: create(:workflow, account: account), status: 'paused')
        expect { enrollment.pause!(reason: 'manual') }.to raise_error(RuntimeError, /Cannot pause/)
      end

      it 'raises when completed' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: create(:workflow, account: account), status: 'completed')
        expect { enrollment.pause!(reason: 'manual') }.to raise_error(RuntimeError, /Cannot pause/)
      end

      it 'raises when cancelled' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: create(:workflow, account: account), status: 'cancelled')
        expect { enrollment.pause!(reason: 'manual') }.to raise_error(RuntimeError, /Cannot pause/)
      end
    end

    describe '#resume_to_waiting!' do
      it 'transitions from paused to waiting' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'paused')
        enrollment.resume_to_waiting!(resume_at: 1.hour.from_now)
        expect(enrollment.reload.status).to eq('waiting')
        expect(enrollment.paused_at).to be_nil
        expect(enrollment.pause_reason).to be_nil
      end

      it 'raises when not paused' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        expect { enrollment.resume_to_waiting!(resume_at: 1.hour.from_now) }.to raise_error(RuntimeError, /Cannot resume/)
      end
    end

    describe '#resume_to_active!' do
      it 'transitions from paused to active' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'paused')
        enrollment.resume_to_active!
        expect(enrollment.reload.status).to eq('active')
        expect(enrollment.paused_at).to be_nil
        expect(enrollment.pause_reason).to be_nil
      end

      it 'raises when not paused' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        expect { enrollment.resume_to_active! }.to raise_error(RuntimeError, /Cannot resume/)
      end
    end

    describe '#cancel!' do
      it 'transitions to cancelled with reason' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        enrollment.cancel!('manual')
        expect(enrollment.reload.status).to eq('cancelled')
        expect(enrollment.cancel_reason).to eq('manual')
        expect(enrollment.cancelled_at).to be_present
      end

      it 'skips scheduled step executions' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        execution = create(:workflow_step_execution, workflow_enrollment: enrollment, status: 'scheduled')
        enrollment.cancel!('manual')
        expect(execution.reload.status).to eq('skipped')
      end

      it 'is idempotent when already cancelled' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: create(:workflow, account: account), status: 'cancelled')
        expect { enrollment.cancel!('manual') }.not_to raise_error
      end
    end

    describe '#complete!' do
      it 'transitions to completed' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        enrollment.complete!
        expect(enrollment.reload.status).to eq('completed')
        expect(enrollment.completed_at).to be_present
        expect(enrollment.current_node_id).to be_nil
      end
    end
  end

  describe 'predicate methods' do
    describe '#may_pause?' do
      it 'returns true for active' do
        enrollment = build(:workflow_enrollment, status: 'active')
        expect(enrollment.may_pause?).to be true
      end

      it 'returns true for waiting' do
        enrollment = build(:workflow_enrollment, status: 'waiting')
        expect(enrollment.may_pause?).to be true
      end

      it 'returns false for paused' do
        enrollment = build(:workflow_enrollment, status: 'paused')
        expect(enrollment.may_pause?).to be false
      end

      it 'returns false for completed' do
        enrollment = build(:workflow_enrollment, status: 'completed')
        expect(enrollment.may_pause?).to be false
      end

      it 'returns false for cancelled' do
        enrollment = build(:workflow_enrollment, status: 'cancelled')
        expect(enrollment.may_pause?).to be false
      end
    end

    describe '#may_resume?' do
      it 'returns true for paused' do
        enrollment = build(:workflow_enrollment, status: 'paused')
        expect(enrollment.may_resume?).to be true
      end

      it 'returns false for active' do
        enrollment = build(:workflow_enrollment, status: 'active')
        expect(enrollment.may_resume?).to be false
      end
    end

    describe '#may_cancel?' do
      it 'returns true for active, waiting, paused' do
        %w[active waiting paused].each do |s|
          expect(build(:workflow_enrollment, status: s).may_cancel?).to be true
        end
      end

      it 'returns false for completed and cancelled' do
        %w[completed cancelled].each do |s|
          expect(build(:workflow_enrollment, status: s).may_cancel?).to be false
        end
      end
    end

    describe '#may_run_step?' do
      it 'returns false when cancelled' do
        enrollment = build(:workflow_enrollment, status: 'cancelled')
        expect(enrollment.may_run_step?('node_1')).to be false
      end

      it 'returns false when completed' do
        enrollment = build(:workflow_enrollment, status: 'completed')
        expect(enrollment.may_run_step?('node_1')).to be false
      end

      it 'returns true when current_node_id matches' do
        enrollment = build(:workflow_enrollment, status: 'active', current_node_id: 'node_1')
        expect(enrollment.may_run_step?('node_1')).to be true
      end

      it 'returns true when current_node_id is blank' do
        enrollment = build(:workflow_enrollment, status: 'active', current_node_id: nil)
        expect(enrollment.may_run_step?('node_1')).to be true
      end
    end
  end

  describe 'scopes' do
    describe '.in_progress' do
      it 'includes active, waiting, and paused enrollments' do
        active = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        paused = create(:workflow_enrollment, account: account, conversation: conversation,
                                              workflow: create(:workflow, account: account), status: 'paused')
        waiting = create(:workflow_enrollment, account: account, conversation: conversation,
                                               workflow: create(:workflow, account: account), status: 'waiting')
        _completed = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: create(:workflow, account: account), status: 'completed')
        _cancelled = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: create(:workflow, account: account), status: 'cancelled')

        result = described_class.in_progress
        expect(result).to include(active, paused, waiting)
        expect(result).not_to include(_completed, _cancelled)
      end
    end

    describe '.active_or_waiting' do
      it 'excludes paused enrollments' do
        active = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
        _paused = create(:workflow_enrollment, account: account, conversation: conversation,
                                               workflow: create(:workflow, account: account), status: 'paused')

        result = described_class.active_or_waiting
        expect(result).to include(active)
        expect(result).not_to include(_paused)
      end
    end
  end

  describe '.handle_contact_reply!' do
    it 'delegates to EnrollmentControlService for in_progress enrollments' do
      enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'waiting')
      service = instance_double(Workflows::EnrollmentControlService)
      allow(Workflows::EnrollmentControlService).to receive(:new).and_return(service)
      allow(service).to receive(:handle_contact_reply)

      described_class.handle_contact_reply!(conversation)

      expect(service).to have_received(:handle_contact_reply).with(enrollment)
    end

    it 'skips completed enrollments' do
      create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'completed')
      service = instance_double(Workflows::EnrollmentControlService)
      allow(Workflows::EnrollmentControlService).to receive(:new).and_return(service)
      allow(service).to receive(:handle_contact_reply)

      described_class.handle_contact_reply!(conversation)

      expect(service).not_to have_received(:handle_contact_reply)
    end
  end

  describe '.cancel_for_conversation!' do
    it 'cancels active enrollments for the conversation' do
      enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
      described_class.cancel_for_conversation!(conversation, reason: 'contact_replied')
      expect(enrollment.reload.status).to eq('cancelled')
    end

    it 'cancels paused enrollments for the conversation' do
      enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'paused')
      described_class.cancel_for_conversation!(conversation, reason: 'conversation_resolved')
      expect(enrollment.reload.status).to eq('cancelled')
    end

    it 'respects cancel_on_contact_reply setting' do
      graph_no_cancel = workflow.graph.merge('settings' => { 'cancel_on_contact_reply' => false })
      no_cancel_workflow = create(:workflow, account: account, graph: graph_no_cancel)
      enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                workflow: no_cancel_workflow, status: 'active')
      described_class.cancel_for_conversation!(conversation, reason: 'contact_replied')
      expect(enrollment.reload.status).to eq('active')
    end
  end
end
