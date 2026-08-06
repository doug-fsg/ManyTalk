# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::EnrollmentPayloadBuilder do
  let(:account) { create(:account) }
  let(:graph) do
    {
      'nodes' => [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'manual' } },
        { 'id' => 'action_1', 'type' => 'action', 'data' => { 'action_name' => 'send_message', 'action_params' => ['Hello'] } },
        { 'id' => 'wait_1', 'type' => 'wait', 'data' => { 'duration' => 6, 'unit' => 'hours' } }
      ],
      'edges' => [
        { 'source' => 'trigger_1', 'target' => 'action_1' },
        { 'source' => 'action_1', 'target' => 'wait_1' }
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

  describe '.for_action_cable' do
    it 'includes human-readable current node label and type' do
      payload = described_class.for_action_cable(enrollment)

      expect(payload[:current_node_label]).to eq('Espera · 6 hora(s)')
      expect(payload[:current_node_type]).to eq('wait')
      expect(payload[:workflow_name]).to eq(workflow.name)
    end
  end
end
