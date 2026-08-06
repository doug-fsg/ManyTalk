# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::TimelineBuilder do
  let(:account) { create(:account) }
  let(:graph) do
    {
      'nodes' => [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'manual' } },
        { 'id' => 'action_1', 'type' => 'action', 'data' => { 'label' => 'Mensagem 1', 'action_name' => 'send_message', 'action_params' => ['Hi'] } },
        { 'id' => 'wait_1', 'type' => 'wait', 'data' => { 'label' => 'Espera 6h', 'duration' => 6, 'unit' => 'hours' } },
        { 'id' => 'action_2', 'type' => 'action', 'data' => { 'label' => 'Mensagem 2', 'action_name' => 'send_message', 'action_params' => ['Follow up'] } }
      ],
      'edges' => [
        { 'source' => 'trigger_1', 'target' => 'action_1' },
        { 'source' => 'action_1', 'target' => 'wait_1' },
        { 'source' => 'wait_1', 'target' => 'action_2' }
      ],
      'settings' => Workflows::Constants::DEFAULT_SETTINGS
    }
  end
  let(:workflow) { create(:workflow, account: account, graph: graph) }
  let(:conversation) { create(:conversation, account: account) }
  let(:enrollment) do
    create(:workflow_enrollment,
           workflow: workflow,
           conversation: conversation,
           account: account,
           status: 'waiting',
           current_node_id: 'wait_1')
  end

  before do
    create(:workflow_step_execution,
           workflow_enrollment: enrollment,
           node_id: 'action_1',
           status: 'completed',
           executed_at: 1.hour.ago)
  end

  it 'builds timeline along the active path' do
    result = described_class.new(enrollment).build

    expect(result[:timeline].map { |s| s[:node_id] }).to eq(%w[trigger_1 action_1 wait_1 action_2])
    expect(result[:total_steps]).to eq(4)
  end

  it 'marks completed and running steps' do
    result = described_class.new(enrollment).build
    action_step = result[:timeline].find { |s| s[:node_id] == 'action_1' }
    wait_step = result[:timeline].find { |s| s[:node_id] == 'wait_1' }

    expect(action_step[:status]).to eq('completed')
    expect(wait_step[:status]).to eq('running')
  end

  it 'includes action_details for action steps' do
    result = described_class.new(enrollment).build
    action_step = result[:timeline].find { |s| s[:node_id] == 'action_1' }

    expect(action_step[:action_details]).to eq(['Enviar uma mensagem: Hi'])
  end

  it 'omits action_details for non-action steps' do
    result = described_class.new(enrollment).build
    wait_step = result[:timeline].find { |s| s[:node_id] == 'wait_1' }

    expect(wait_step[:action_details]).to eq([])
  end
end
