# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::EnrollmentSummaryService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:graph) do
    {
      'nodes' => [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'manual' } },
        { 'id' => 'wait_1', 'type' => 'wait', 'data' => { 'duration' => 6, 'unit' => 'hours' } }
      ],
      'edges' => [
        { 'source' => 'trigger_1', 'target' => 'wait_1' }
      ],
      'settings' => Workflows::Constants::DEFAULT_SETTINGS
    }
  end
  let(:workflow) { create(:workflow, account: account, graph: graph, name: 'Boas-vindas') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:enrollment) do
    create(:workflow_enrollment,
           workflow: workflow,
           conversation: conversation,
           account: account,
           status: 'waiting',
           current_node_id: 'wait_1')
  end

  before do
    Current.account = account
    create(:inbox_member, user: agent, inbox: inbox)
    create(:workflow_step_execution,
           workflow_enrollment: enrollment,
           node_id: 'trigger_1',
           status: 'completed',
           executed_at: 1.hour.ago)
  end

  after { Current.account = nil }

  def build_for(user, ids)
    described_class.new(account: account, user: user, conversation_ids: ids).build
  end

  it 'does not walk TimelineBuilder for list badges' do
    expect(Workflows::TimelineBuilder).not_to receive(:new)

    result = build_for(admin, [conversation.id])
    summary = result[:summaries][conversation.id]

    expect(summary[:enrollment_id]).to eq(enrollment.id)
    expect(summary[:workflow_name]).to eq('Boas-vindas')
    expect(summary[:status]).to eq('waiting')
    expect(summary[:current_node_type]).to eq('wait')
    expect(summary).not_to have_key(:step_index)
    expect(summary).not_to have_key(:total_steps)
  end

  it 'indexes the same payload by display_id when requested' do
    result = build_for(admin, [conversation.display_id])
    expect(result[:summaries][conversation.display_id][:enrollment_id]).to eq(enrollment.id)
  end

  it 'scopes enrollments to assigned inboxes for agents' do
    hidden_inbox = create(:inbox, account: account)
    hidden_conversation = create(:conversation, account: account, inbox: hidden_inbox)
    create(:workflow_enrollment,
           workflow: workflow,
           conversation: hidden_conversation,
           account: account,
           status: 'waiting',
           current_node_id: 'wait_1')

    result = build_for(agent, [conversation.id, hidden_conversation.id])

    expect(result[:summaries].keys).to include(conversation.id)
    expect(result[:summaries].keys).not_to include(hidden_conversation.id)
  end

  it 'returns an empty hash when no conversation ids are given' do
    expect(build_for(admin, [])).to eq(summaries: {})
  end
end
