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

  it 'accepts valid ai_outreach node when inteligencia_artificial is enabled' do
    account.enable_features!('inteligencia_artificial')
    graph = build(:workflow).graph
    graph['nodes'] << {
      'id' => 'ai_1',
      'type' => 'ai_outreach',
      'data' => {
        'objective_preset' => 'reengagement',
        'tone_preset' => 'friendly',
        'language' => 'client',
        'prompt' => 'Retome o contato com o cliente de forma amigável.',
        'prompt_customized' => false
      }
    }
    graph['edges'] << { 'id' => 'e_ai', 'source' => 'trigger_1', 'target' => 'ai_1' }

    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be true
  end

  it 'rejects ai_outreach node without inteligencia_artificial feature' do
    graph = build(:workflow).graph
    graph['nodes'] << {
      'id' => 'ai_1',
      'type' => 'ai_outreach',
      'data' => {
        'objective_preset' => 'reengagement',
        'tone_preset' => 'friendly',
        'language' => 'client',
        'prompt' => 'Retome o contato com o cliente de forma amigável.',
        'prompt_customized' => false
      }
    }
    graph['edges'] << { 'id' => 'e_ai', 'source' => 'trigger_1', 'target' => 'ai_1' }

    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be false
    expect(result[:errors].map { |e| e[:message] }).to include(
      'AI outreach requires the inteligencia_artificial feature'
    )
  end

  it 'rejects ai_outreach node without prompt' do
    account.enable_features!('inteligencia_artificial')
    graph = build(:workflow).graph
    graph['nodes'] << {
      'id' => 'ai_1',
      'type' => 'ai_outreach',
      'data' => {
        'objective_preset' => 'reengagement',
        'tone_preset' => 'friendly',
        'prompt' => ''
      }
    }
    graph['edges'] << { 'id' => 'e_ai', 'source' => 'trigger_1', 'target' => 'ai_1' }

    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be false
  end

  it 'rejects wait_for_reply edge without valid sourceHandle' do
    graph = build(:workflow).graph
    graph['nodes'] << {
      'id' => 'wait_reply_1',
      'type' => 'wait_for_reply',
      'data' => { 'duration' => 1, 'unit' => 'hours' }
    }
    graph['nodes'] << {
      'id' => 'action_timeout',
      'type' => 'action',
      'data' => { 'action_name' => 'add_label', 'action_params' => ['timeout'] }
    }
    graph['edges'] << { 'id' => 'e_wr', 'source' => 'trigger_1', 'target' => 'wait_reply_1' }
    graph['edges'] << { 'id' => 'e_bad', 'source' => 'wait_reply_1', 'target' => 'action_timeout' }

    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be false
    expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('replied or timeout')
  end

  it 'accepts valid wait_for_reply graph' do
    graph = build(:workflow).graph
    graph['nodes'] << {
      'id' => 'wait_reply_1',
      'type' => 'wait_for_reply',
      'data' => { 'duration' => 1, 'unit' => 'hours' }
    }
    graph['nodes'] << {
      'id' => 'action_timeout',
      'type' => 'action',
      'data' => { 'action_name' => 'add_label', 'action_params' => ['timeout'] }
    }
    graph['edges'] << { 'id' => 'e_wr', 'source' => 'trigger_1', 'target' => 'wait_reply_1' }
    graph['edges'] << {
      'id' => 'e_to',
      'source' => 'wait_reply_1',
      'target' => 'action_timeout',
      'sourceHandle' => 'timeout'
    }

    result = described_class.new(graph: graph, account: account).perform
    expect(result[:valid]).to be true
  end
end
