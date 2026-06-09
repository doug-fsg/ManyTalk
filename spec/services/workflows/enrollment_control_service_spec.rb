# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::EnrollmentControlService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:graph) do
    {
      'nodes' => [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'manual' } },
        { 'id' => 'wait_1', 'type' => 'wait', 'data' => { 'duration' => 6, 'unit' => 'hours' } },
        { 'id' => 'action_1', 'type' => 'action', 'data' => { 'action_name' => 'send_message', 'action_params' => ['Hello'] } }
      ],
      'edges' => [
        { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'wait_1' },
        { 'id' => 'e2', 'source' => 'wait_1', 'target' => 'action_1' }
      ],
      'settings' => Workflows::Constants::DEFAULT_SETTINGS
    }
  end
  let(:workflow) { create(:workflow, account: account, graph: graph, active: true) }

  before do
    account.enable_features!('workflows')
    allow(Workflows::EnrollmentBroadcaster).to receive(:updated)
  end

  subject { described_class.new }

  describe '#start' do
    before { allow(Workflows::OrchestratorService).to receive(:advance_from_node) }

    it 'creates an enrollment' do
      result = subject.start(conversation: conversation, workflow: workflow, user: user)
      expect(result[:enrollment]).to be_persisted
      expect(result[:enrollment].status).to eq('active')
      expect(result[:enrollment].started_by).to eq(user)
    end

    it 'sets current_node_id to the trigger node' do
      result = subject.start(conversation: conversation, workflow: workflow, user: user)
      expect(result[:enrollment].current_node_id).to eq('trigger_1')
    end

    it 'calls advance_from_node on the orchestrator' do
      subject.start(conversation: conversation, workflow: workflow, user: user)
      expect(Workflows::OrchestratorService).to have_received(:advance_from_node)
        .with(workflow, anything, conversation, 'trigger_1')
    end

    it 'broadcasts the enrollment update' do
      subject.start(conversation: conversation, workflow: workflow, user: user)
      expect(Workflows::EnrollmentBroadcaster).to have_received(:updated)
    end

    it 'returns conflict error for duplicate enrollment' do
      subject.start(conversation: conversation, workflow: workflow, user: user)
      result = subject.start(conversation: conversation, workflow: workflow, user: user)
      expect(result[:error]).to eq(:conflict)
    end
  end

  describe '#pause' do
    let!(:enrollment) do
      create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'waiting')
    end

    it 'pauses an active/waiting enrollment' do
      result = subject.pause(enrollment: enrollment, user: user, reason: 'manual')
      expect(result[:enrollment].status).to eq('paused')
      expect(result[:enrollment].paused_by).to eq(user)
    end

    it 'cancels pending scheduled jobs' do
      create(:workflow_step_execution, workflow_enrollment: enrollment, node_id: 'wait_1', status: 'scheduled')
      allow(Workflows::JobScheduler).to receive(:cancel_pending!)
      subject.pause(enrollment: enrollment, user: user)
      expect(Workflows::JobScheduler).to have_received(:cancel_pending!).with(enrollment)
    end

    it 'preserves resume_at from the pending step execution' do
      future = 3.hours.from_now
      create(:workflow_step_execution, workflow_enrollment: enrollment, node_id: 'wait_1',
                                       status: 'scheduled', scheduled_at: future)
      result = subject.pause(enrollment: enrollment, user: user)
      expect(result[:enrollment].resume_at).to be_within(1.second).of(future)
    end

    it 'returns error for already paused enrollment' do
      enrollment.update!(status: 'paused')
      result = subject.pause(enrollment: enrollment, user: user)
      expect(result[:error]).to eq(:invalid_transition)
    end

    it 'returns error for completed enrollment' do
      enrollment.update!(status: 'completed')
      result = subject.pause(enrollment: enrollment, user: user)
      expect(result[:error]).to eq(:invalid_transition)
    end
  end

  describe '#resume' do
    let!(:enrollment) do
      create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow,
                                   status: 'paused', current_node_id: 'wait_1', resume_at: 2.hours.from_now)
    end

    it 'resumes to waiting when current node is a wait node' do
      allow(Workflows::JobScheduler).to receive(:schedule)
      result = subject.resume(enrollment: enrollment, user: user)
      expect(result[:enrollment].status).to eq('waiting')
    end

    it 'reschedules the job with remaining delay' do
      allow(Workflows::JobScheduler).to receive(:schedule)
      subject.resume(enrollment: enrollment, user: user)
      expect(Workflows::JobScheduler).to have_received(:schedule).with(enrollment, 'wait_1', anything)
    end

    it 'resumes to active when current node is not a wait node' do
      enrollment.update!(current_node_id: 'action_1', resume_at: nil)
      allow(Workflows::OrchestratorService).to receive(:advance_from_node)
      result = subject.resume(enrollment: enrollment, user: user)
      expect(result[:enrollment].status).to eq('active')
    end

    it 'returns error when not paused' do
      enrollment.update!(status: 'active')
      result = subject.resume(enrollment: enrollment, user: user)
      expect(result[:error]).to eq(:invalid_transition)
    end
  end

  describe '#cancel' do
    let!(:enrollment) do
      create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')
    end

    it 'cancels the enrollment' do
      result = subject.cancel(enrollment: enrollment, user: user, reason: 'manual')
      expect(result[:enrollment].status).to eq('cancelled')
      expect(result[:enrollment].cancel_reason).to eq('manual')
    end

    it 'cancels pending scheduled jobs' do
      allow(Workflows::JobScheduler).to receive(:cancel_pending!)
      subject.cancel(enrollment: enrollment, user: user)
      expect(Workflows::JobScheduler).to have_received(:cancel_pending!).with(enrollment)
    end

    it 'broadcasts the enrollment update' do
      subject.cancel(enrollment: enrollment, user: user)
      expect(Workflows::EnrollmentBroadcaster).to have_received(:updated)
    end

    it 'returns error for completed enrollment' do
      enrollment.update!(status: 'completed')
      result = subject.cancel(enrollment: enrollment, user: user)
      expect(result[:error]).to eq(:invalid_transition)
    end
  end

  describe '#jump_to_node' do
    let!(:enrollment) do
      create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow,
                                   status: 'paused', current_node_id: 'wait_1')
    end

    before { allow(Workflows::OrchestratorService).to receive(:advance_from_node) }

    it 'jumps to the specified node' do
      result = subject.jump_to_node(enrollment: enrollment, node_id: 'action_1', user: user)
      expect(result[:enrollment].current_node_id).to eq('action_1')
      expect(result[:enrollment].status).to eq('active')
    end

    it 'clears pause state' do
      enrollment.update!(paused_at: Time.current, pause_reason: 'manual')
      result = subject.jump_to_node(enrollment: enrollment, node_id: 'action_1', user: user)
      expect(result[:enrollment].paused_at).to be_nil
      expect(result[:enrollment].pause_reason).to be_nil
    end

    it 'skips previously scheduled step executions' do
      execution = create(:workflow_step_execution, workflow_enrollment: enrollment, node_id: 'wait_1', status: 'scheduled')
      subject.jump_to_node(enrollment: enrollment, node_id: 'action_1', user: user)
      expect(execution.reload.status).to eq('skipped')
    end

    it 'returns error for non-existent node' do
      result = subject.jump_to_node(enrollment: enrollment, node_id: 'nonexistent', user: user)
      expect(result[:error]).to eq(:node_not_found)
    end
  end

  describe '#handle_contact_reply' do
    it 'branches instead of pausing when reply_watch is active' do
      enrollment = create(
        :workflow_enrollment,
        account: account,
        conversation: conversation,
        workflow: workflow,
        status: 'waiting',
        current_node_id: 'wait_reply_1',
        context: {
          'reply_watch' => {
            'node_id' => 'wait_reply_1',
            'baseline_at' => 1.hour.ago.iso8601(6),
            'deadline_at' => 1.hour.from_now.iso8601(6)
          }
        }
      )
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'Resposta')

      allow(Workflows::OrchestratorService).to receive(:on_contact_reply)

      subject.handle_contact_reply(enrollment)

      expect(Workflows::OrchestratorService).to have_received(:on_contact_reply).with(enrollment)
      expect(enrollment.reload.status).to eq('waiting')
    end

    it 'pauses enrollment when pause_on_contact_reply is true (default)' do
      enrollment = create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'waiting')
      subject.handle_contact_reply(enrollment)
      expect(enrollment.reload.status).to eq('paused')
    end

    it 'cancels enrollment when pause is disabled but cancel is enabled' do
      settings = Workflows::Constants::DEFAULT_SETTINGS.merge(
        'pause_on_contact_reply' => false,
        'cancel_on_contact_reply' => true
      )
      graph_with_cancel = graph.merge('settings' => settings)
      cancel_workflow = create(:workflow, account: account, graph: graph_with_cancel, active: true)
      enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                workflow: cancel_workflow, status: 'waiting')
      subject.handle_contact_reply(enrollment)
      expect(enrollment.reload.status).to eq('cancelled')
    end

    it 'does nothing when both pause and cancel are disabled' do
      settings = Workflows::Constants::DEFAULT_SETTINGS.merge(
        'pause_on_contact_reply' => false,
        'cancel_on_contact_reply' => false
      )
      graph_no_action = graph.merge('settings' => settings)
      no_action_workflow = create(:workflow, account: account, graph: graph_no_action, active: true)
      enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                workflow: no_action_workflow, status: 'waiting')
      subject.handle_contact_reply(enrollment)
      expect(enrollment.reload.status).to eq('waiting')
    end
  end
end
