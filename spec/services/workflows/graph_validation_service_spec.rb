# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::GraphValidationService do
  let(:account) { create(:account) }

  it 'validates a minimal valid graph' do
    graph = build(:workflow).graph
    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be true
  end

  it 'validates graph passed as ActionController::Parameters' do
    graph = build(:workflow).graph
    params = ActionController::Parameters.new(graph)
    parsed = Workflows::GraphParamsParser.to_hash(params)
    result = described_class.new(graph: parsed, account: account).perform
    expect(result[:valid]).to be true
  end

  it 'rejects graph without trigger' do
    graph = { 'nodes' => [], 'edges' => [] }
    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be false
  end

  it 'rejects invalid action name' do
    graph = build(:workflow).graph
    graph['nodes'] << {
      'id' => 'bad_action',
      'type' => 'action',
      'data' => { 'action_name' => 'invalid_action', 'action_params' => [] }
    }
    graph['edges'] << { 'id' => 'e2', 'source' => 'trigger_1', 'target' => 'bad_action' }
    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be false
  end

  it 'rejects edge whose target is the trigger node' do
    graph = build(:workflow).graph
    graph['edges'] << { 'id' => 'e_bad', 'source' => 'action_1', 'target' => 'trigger_1' }
    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be false
    expect(result[:errors].join).to include('trigger')
  end
end
