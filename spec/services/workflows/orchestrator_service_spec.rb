# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::OrchestratorService do
  let(:account) { create(:account) }

  before { account.enable_features!('workflows') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

  describe '.on_event' do
    let!(:workflow) { create(:workflow, account: account, active: true) }
    it 'creates enrollment when trigger matches' do
      expect do
        described_class.on_event(
          event_name: 'conversation_created',
          account_id: account.id,
          conversation_id: conversation.id
        )
      end.to change(WorkflowEnrollment, :count).by(1)
    end

    it 'does not create duplicate enrollment' do
      create(:workflow_enrollment, workflow: workflow, conversation: conversation, account: account, status: 'active')
      expect do
        described_class.on_event(
          event_name: 'conversation_created',
          account_id: account.id,
          conversation_id: conversation.id
        )
      end.not_to change(WorkflowEnrollment, :count)
    end

    it 'does not process events when workflows feature is disabled' do
      account.disable_features!('workflows')

      expect do
        described_class.on_event(
          event_name: 'conversation_created',
          account_id: account.id,
          conversation_id: conversation.id
        )
      end.not_to change(WorkflowEnrollment, :count)
    end
  end

  describe 'wait node' do
    let(:wait_graph) do
      {
        'nodes' => [
          {
            'id' => 'trigger_1',
            'type' => 'trigger',
            'data' => { 'event_name' => 'conversation_created', 'conditions' => [] }
          },
          {
            'id' => 'wait_1',
            'type' => 'wait',
            'data' => { 'duration' => 1, 'unit' => 'minutes' }
          }
        ],
        'edges' => [
          { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'wait_1' }
        ],
        'settings' => {
          'cancel_on_contact_reply' => true,
          'cancel_on_conversation_resolved' => true
        }
      }
    end

    let!(:workflow) { create(:workflow, account: account, active: true, graph: wait_graph) }

    before { clear_enqueued_jobs }

    it 'sets enrollment to waiting and schedules step execution' do
      freeze_time do
        expect do
          described_class.on_event(
            event_name: 'conversation_created',
            account_id: account.id,
            conversation_id: conversation.id
          )
        end.to have_enqueued_job(Workflows::StepJob)

        enrollment = WorkflowEnrollment.last
        expect(enrollment.status).to eq('waiting')
        expect(enrollment.current_node_id).to eq('wait_1')

        execution = enrollment.workflow_step_executions.find_by!(node_id: 'wait_1')
        expect(execution.status).to eq('scheduled')
        expect(execution.scheduled_at).to eq(1.minute.from_now)
      end
    end

    it 'schedules at least one second ahead when duration is zero' do
      freeze_time do
        workflow.update_column(
          :graph,
          wait_graph.merge(
            'nodes' => [
              wait_graph['nodes'].first,
              { 'id' => 'wait_1', 'type' => 'wait', 'data' => { 'duration' => 0, 'unit' => 'hours' } }
            ]
          )
        )

        described_class.on_event(
          event_name: 'conversation_created',
          account_id: account.id,
          conversation_id: conversation.id
        )

        enrollment = WorkflowEnrollment.last
        execution = enrollment.workflow_step_executions.find_by!(node_id: 'wait_1')
        expect(execution.scheduled_at).to eq(1.second.from_now)
      end
    end

    it 'completes enrollment when wait expires and there is no next node' do
      travel_to Time.zone.parse('2025-06-01 12:00:00') do
        clear_enqueued_jobs
        described_class.on_event(
          event_name: 'conversation_created',
          account_id: account.id,
          conversation_id: conversation.id
        )
      end

      enrollment = WorkflowEnrollment.last
      run_at = enrollment.workflow_step_executions.find_by!(node_id: 'wait_1').scheduled_at

      travel_to run_at + 1.second do
        perform_enqueued_jobs(only: Workflows::StepJob)
      end

      expect(enrollment.reload.status).to eq('completed')
    end
  end

  describe 'cancel_for_conversation' do
    let!(:workflow) { create(:workflow, account: account, active: true) }
    let!(:enrollment) do
      create(:workflow_enrollment, workflow: workflow, conversation: conversation, account: account, status: 'waiting')
    end

    it 'cancels on contact reply' do
      WorkflowEnrollment.cancel_for_conversation!(conversation, reason: 'contact_replied')
      expect(enrollment.reload.status).to eq('cancelled')
    end
  end
end
