# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::GraphParamsParser do
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
      'settings' => { 'cancel_on_contact_reply' => true }
    }
  end

  it 'converts ActionController::Parameters to hash' do
    params = ActionController::Parameters.new(graph_hash)
    result = described_class.to_hash(params)

    expect(result).to be_a(Hash)
    expect(result['nodes']).to be_an(Array)
    expect(result['nodes'].first['type']).to eq('trigger')
    expect(result['edges']).to eq([])
  end

  it 'returns empty hash for nil' do
    expect(described_class.to_hash(nil)).to eq({})
  end
end
