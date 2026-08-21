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

    it 'does not create duplicate enrollment when one is paused' do
      create(:workflow_enrollment, workflow: workflow, conversation: conversation, account: account, status: 'paused')
      expect do
        described_class.on_event(
          event_name: 'conversation_created',
          account_id: account.id,
          conversation_id: conversation.id
        )
      end.not_to change(WorkflowEnrollment, :count)
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

  describe 'wait_for_reply node' do
    let(:wait_reply_graph) do
      {
        'nodes' => [
          {
            'id' => 'trigger_1',
            'type' => 'trigger',
            'data' => { 'event_name' => 'conversation_created', 'conditions' => [] }
          },
          {
            'id' => 'wait_reply_1',
            'type' => 'wait_for_reply',
            'data' => { 'duration' => 1, 'unit' => 'hours', 'label' => 'Aguardar resposta' }
          },
          {
            'id' => 'action_replied',
            'type' => 'action',
            'data' => { 'action_name' => 'add_label', 'action_params' => ['replied'] }
          },
          {
            'id' => 'action_timeout',
            'type' => 'action',
            'data' => { 'action_name' => 'add_label', 'action_params' => ['timeout'] }
          }
        ],
        'edges' => [
          { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'wait_reply_1' },
          { 'id' => 'e2', 'source' => 'wait_reply_1', 'target' => 'action_replied', 'sourceHandle' => 'replied' },
          { 'id' => 'e3', 'source' => 'wait_reply_1', 'target' => 'action_timeout', 'sourceHandle' => 'timeout' }
        ],
        'settings' => Workflows::Constants::DEFAULT_SETTINGS
      }
    end

    let!(:workflow) { create(:workflow, account: account, active: true, graph: wait_reply_graph) }

    before { clear_enqueued_jobs }

    it 'sets reply_watch context and waiting status' do
      freeze_time do
        described_class.on_event(
          event_name: 'conversation_created',
          account_id: account.id,
          conversation_id: conversation.id
        )

        enrollment = WorkflowEnrollment.last
        expect(enrollment.status).to eq('waiting')
        expect(enrollment.current_node_id).to eq('wait_reply_1')
        expect(enrollment.reply_watch_active?).to be true
        expect(enrollment.reply_watch['deadline_at']).to be_present
      end
    end

    it 'branches to replied path when contact replies' do
      described_class.on_event(
        event_name: 'conversation_created',
        account_id: account.id,
        conversation_id: conversation.id
      )
      enrollment = WorkflowEnrollment.last

      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'Oi')

      described_class.on_contact_reply(enrollment)

      expect(enrollment.reload.reply_watch_active?).to be false
      expect(enrollment.status).to eq('completed')
    end

    it 'branches to timeout path when deadline expires without reply' do
      travel_to Time.zone.parse('2025-06-01 12:00:00') do
        described_class.on_event(
          event_name: 'conversation_created',
          account_id: account.id,
          conversation_id: conversation.id
        )
      end

      enrollment = WorkflowEnrollment.last
      run_at = enrollment.workflow_step_executions.find_by!(node_id: 'wait_reply_1').scheduled_at

      travel_to run_at + 1.second do
        perform_enqueued_jobs(only: Workflows::StepJob)
      end

      expect(enrollment.reload.reply_watch_active?).to be false
      expect(enrollment.status).to eq('completed')
    end
  end

  describe 'ai_outreach node' do
    let(:ai_url) { 'https://n8n.example.com/webhook/ai' }
    let(:api_inbox) { create(:inbox, account: account) }
    let(:api_contact) { create(:contact, account: account, name: 'Maria') }
    let(:api_contact_inbox) { create(:contact_inbox, contact: api_contact, inbox: api_inbox) }
    let(:api_conversation) do
      create(:conversation, account: account, inbox: api_inbox, contact: api_contact, contact_inbox: api_contact_inbox)
    end
    let(:ai_graph) do
      {
        'nodes' => [
          {
            'id' => 'trigger_1',
            'type' => 'trigger',
            'data' => { 'event_name' => 'conversation_created', 'conditions' => [] }
          },
          {
            'id' => 'ai_1',
            'type' => 'ai_outreach',
            'data' => {
              'objective_preset' => 'reengagement',
              'tone_preset' => 'friendly',
              'language' => 'client',
              'prompt' => 'Retome o contato com o cliente de forma amigável.',
              'prompt_customized' => false,
              'include_last_messages' => true
            }
          }
        ],
        'edges' => [
          { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'ai_1' }
        ],
        'settings' => {
          'cancel_on_contact_reply' => true,
          'cancel_on_conversation_resolved' => true
        }
      }
    end

    let!(:workflow) { create(:workflow, account: account, active: true, graph: ai_graph) }

    before do
      account.enable_features!('inteligencia_artificial')
      allow(Workflows::AiWebhook).to receive(:url).and_return(ai_url)
    end

    it 'enqueues WORKFLOW_AI_URL webhook when enrollment reaches ai_outreach node' do
      expect(WebhookJob).to receive(:perform_later).with(
        ai_url,
        hash_including(
          event: 'workflow.ai_outreach',
          prompt: include('cliente'),
          workflow_node_id: 'ai_1'
        )
      )

      described_class.on_event(
        event_name: 'conversation_created',
        account_id: account.id,
        conversation_id: api_conversation.id
      )

      expect(WorkflowEnrollment.last.status).to eq('completed')
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
