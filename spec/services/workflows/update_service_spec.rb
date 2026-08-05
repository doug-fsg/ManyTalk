# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::UpdateService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:graph) do
    {
      'nodes' => [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'manual' } },
        { 'id' => 'action_1', 'type' => 'action', 'data' => { 'action_name' => 'send_message', 'action_params' => ['Hi'] } }
      ],
      'edges' => [{ 'source' => 'trigger_1', 'target' => 'action_1' }],
      'settings' => Workflows::Constants::DEFAULT_SETTINGS
    }
  end
  let(:workflow) { create(:workflow, account: account, active: true, graph: graph) }

  describe 'settings-only update on active workflow' do
    it 'updates settings without deactivating' do
      params = {
        graph: graph.merge(
          'settings' => graph['settings'].merge('cancel_on_agent_reply' => true)
        )
      }

      result = described_class.new(workflow: workflow, user: user, params: params).perform

      expect(result[:errors]).to be_empty
      expect(workflow.reload.settings['cancel_on_agent_reply']).to be true
      expect(workflow.active?).to be true
    end

    it 'rejects structural graph changes while active' do
      params = {
        graph: graph.merge(
          'nodes' => graph['nodes'] + [
            { 'id' => 'action_2', 'type' => 'action', 'data' => { 'action_name' => 'send_message', 'action_params' => ['Bye'] } }
          ]
        )
      }

      result = described_class.new(workflow: workflow, user: user, params: params).perform

      expect(result[:errors]).to be_present
      expect(workflow.reload.graph['nodes'].size).to eq(2)
    end
  end
end
