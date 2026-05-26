# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::CreateService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  let(:graph_hash) do
    {
      'nodes' => [
        {
          'id' => 'trigger_1',
          'type' => 'trigger',
          'data' => { 'event_name' => 'conversation_created', 'conditions' => [] }
        }
      ],
      'edges' => [],
      'settings' => {
        'cancel_on_contact_reply' => true,
        'cancel_on_conversation_resolved' => true
      }
    }
  end

  it 'creates workflow when graph is ActionController::Parameters' do
    params = ActionController::Parameters.new(
      name: 'Test flow',
      description: 'Desc',
      active: false,
      graph: graph_hash
    )

    result = described_class.new(account: account, user: user, params: params).perform

    expect(result[:errors]).to eq([])
    expect(result[:workflow]).to be_persisted
    expect(result[:workflow].graph['nodes']).to be_an(Array)
    expect(result[:workflow].trigger_event_name).to eq('conversation_created')
  end

  it 'returns validation errors when graph is missing' do
    params = ActionController::Parameters.new(name: 'Empty', active: false)

    result = described_class.new(account: account, user: user, params: params).perform

    expect(result[:workflow]).to be_nil
    expect(result[:errors]).to include('Graph must include nodes array')
  end
end
