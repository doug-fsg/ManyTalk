# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::GraphValidationService do
  let(:account) { create(:account) }

  before do
    allow(account).to receive(:feature_enabled?).with('inteligencia_artificial').and_return(true)
  end

  def graph_with_intent_node(intent_key: 'schedule_visit', duration: 30, unit: 'minutes')
    {
      'nodes' => [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'conversation_created' } },
        {
          'id' => 'intent_1',
          'type' => 'ai_wait_for_intent',
          'data' => { 'intent_key' => intent_key, 'duration' => duration, 'unit' => unit }
        },
        { 'id' => 'action_1', 'type' => 'action', 'data' => { 'action_name' => 'send_message', 'action_params' => ['hi'] } },
        { 'id' => 'action_2', 'type' => 'action', 'data' => { 'action_name' => 'send_message', 'action_params' => ['timeout'] } }
      ],
      'edges' => [
        { 'source' => 'trigger_1', 'target' => 'intent_1' },
        { 'source' => 'intent_1', 'target' => 'action_1', 'sourceHandle' => 'intent_detected' },
        { 'source' => 'intent_1', 'target' => 'action_2', 'sourceHandle' => 'timeout' }
      ]
    }
  end

  describe 'ai_wait_for_intent node' do
    it 'is valid with correct intent_key and duration' do
      result = described_class.new(graph: graph_with_intent_node, account: account).perform
      expect(result[:valid]).to be true
    end

    it 'fails with invalid intent_key' do
      result = described_class.new(graph: graph_with_intent_node(intent_key: 'nonexistent'), account: account).perform
      expect(result[:valid]).to be false
      expect(result[:errors].map { |e| e[:message] }).to include(match(/intent_key/))
    end

    it 'fails with blank intent_key' do
      result = described_class.new(graph: graph_with_intent_node(intent_key: ''), account: account).perform
      expect(result[:valid]).to be false
    end

    it 'fails with wrong sourceHandle on edges' do
      bad_graph = graph_with_intent_node
      bad_graph['edges'][1]['sourceHandle'] = 'replied'
      result = described_class.new(graph: bad_graph, account: account).perform
      expect(result[:valid]).to be false
    end

    it 'requires feature flag' do
      allow(account).to receive(:feature_enabled?).with('inteligencia_artificial').and_return(false)
      result = described_class.new(graph: graph_with_intent_node, account: account).perform
      expect(result[:valid]).to be false
      expect(result[:errors].map { |e| e[:message] }).to include(match(/inteligencia_artificial/))
    end

    it 'counts toward the combined wait node limit' do
      nodes = [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'conversation_created' } }
      ]
      edges = []
      11.times do |i|
        nodes << { 'id' => "w#{i}", 'type' => 'wait', 'data' => { 'duration' => 1, 'unit' => 'hours' } }
        edges << { 'source' => i.zero? ? 'trigger_1' : "w#{i - 1}", 'target' => "w#{i}" }
      end
      result = described_class.new(graph: { 'nodes' => nodes, 'edges' => edges }, account: account).perform
      expect(result[:valid]).to be false
      expect(result[:errors].map { |e| e[:message] }).to include(match(/Maximum.*wait/i))
    end
  end
end
