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

  describe 'wait_for_reply node' do
    let(:base_graph) do
      g = build(:workflow).graph
      g['nodes'] << { 'id' => 'wfr', 'type' => 'wait_for_reply', 'data' => { 'duration' => 1, 'unit' => 'hours' } }
      g['nodes'] << { 'id' => 'on_reply', 'type' => 'action', 'data' => { 'action_name' => 'add_label', 'action_params' => ['replied'] } }
      g['nodes'] << { 'id' => 'on_timeout', 'type' => 'action', 'data' => { 'action_name' => 'add_label', 'action_params' => ['timeout'] } }
      g['edges'] << { 'id' => 'e_in', 'source' => 'trigger_1', 'target' => 'wfr' }
      g
    end

    it 'accepts both outgoing edges with correct handles' do
      base_graph['edges'] << { 'id' => 'e_replied', 'source' => 'wfr', 'target' => 'on_reply', 'sourceHandle' => 'replied' }
      base_graph['edges'] << { 'id' => 'e_timeout', 'source' => 'wfr', 'target' => 'on_timeout', 'sourceHandle' => 'timeout' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be true
    end

    it 'accepts a single outgoing edge with replied handle' do
      base_graph['edges'] << { 'id' => 'e_replied', 'source' => 'wfr', 'target' => 'on_reply', 'sourceHandle' => 'replied' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be true
    end

    it 'accepts a single outgoing edge with timeout handle' do
      base_graph['edges'] << { 'id' => 'e_timeout', 'source' => 'wfr', 'target' => 'on_timeout', 'sourceHandle' => 'timeout' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be true
    end

    it 'rejects an outgoing edge with nil sourceHandle' do
      # Missing sourceHandle — common when frontend normalization was skipped
      base_graph['edges'] << { 'id' => 'e_bad', 'source' => 'wfr', 'target' => 'on_reply' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('replied or timeout')
    end

    it 'rejects an outgoing edge with condition handle "true" instead of "replied"' do
      # Cross-type contamination: condition handles leaked into wait_for_reply
      base_graph['edges'] << { 'id' => 'e_bad', 'source' => 'wfr', 'target' => 'on_reply', 'sourceHandle' => 'true' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('replied or timeout')
    end

    it 'rejects an outgoing edge with condition handle "false" instead of "timeout"' do
      base_graph['edges'] << { 'id' => 'e_bad', 'source' => 'wfr', 'target' => 'on_timeout', 'sourceHandle' => 'false' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('replied or timeout')
    end

    it 'rejects when the node has no outgoing edges at all' do
      # No outbound edge added — only the incoming one
      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('outbound connection')
    end

    it 'reports the correct node_id in the error' do
      base_graph['edges'] << { 'id' => 'e_bad', 'source' => 'wfr', 'target' => 'on_reply' }

      result = described_class.new(graph: base_graph, account: account).perform
      error = result[:errors].find { |e| e[:message].include?('replied or timeout') }
      expect(error[:node_id]).to eq('wfr')
    end

    it 'rejects invalid wait_responder' do
      wfr_node = base_graph['nodes'].find { |n| n['id'] == 'wfr' }
      wfr_node['data']['wait_responder'] = 'unknown_role'
      base_graph['edges'] << { 'id' => 'e_replied', 'source' => 'wfr', 'target' => 'on_reply', 'sourceHandle' => 'replied' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('Invalid wait responder')
    end
  end

  describe 'send_whatsapp_external action' do
    let(:base_graph) { build(:workflow).graph }

    it 'accepts action with inbox_id and phone number' do
      base_graph['nodes'] << {
        'id' => 'wa_action',
        'type' => 'action',
        'data' => { 'action_name' => 'send_whatsapp_external', 'action_params' => ['42', '5511999999999', 'Hello'] }
      }
      base_graph['edges'] << { 'id' => 'e_wa', 'source' => 'trigger_1', 'target' => 'wa_action' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be true
    end

    it 'rejects action without inbox_id' do
      base_graph['nodes'] << {
        'id' => 'wa_action',
        'type' => 'action',
        'data' => { 'action_name' => 'send_whatsapp_external', 'action_params' => ['', '5511999999999', 'Hello'] }
      }
      base_graph['edges'] << { 'id' => 'e_wa', 'source' => 'trigger_1', 'target' => 'wa_action' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('requires an inbox')
    end

    it 'rejects action without phone number' do
      base_graph['nodes'] << {
        'id' => 'wa_action',
        'type' => 'action',
        'data' => { 'action_name' => 'send_whatsapp_external', 'action_params' => ['42', '', 'Hello'] }
      }
      base_graph['edges'] << { 'id' => 'e_wa', 'source' => 'trigger_1', 'target' => 'wa_action' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('requires a phone number')
    end

    it 'rejects action with empty action_params' do
      base_graph['nodes'] << {
        'id' => 'wa_action',
        'type' => 'action',
        'data' => { 'action_name' => 'send_whatsapp_external', 'action_params' => [] }
      }
      base_graph['edges'] << { 'id' => 'e_wa', 'source' => 'trigger_1', 'target' => 'wa_action' }

      result = described_class.new(graph: base_graph, account: account).perform
      expect(result[:valid]).to be false
      messages = Workflows::GraphValidationService.error_messages(result[:errors]).join
      expect(messages).to include('requires an inbox')
      expect(messages).to include('requires a phone number')
    end
  end

  it 'rejects wait_for_reply edge without valid sourceHandle (legacy test)' do
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

  it 'accepts valid wait_for_reply graph (legacy test)' do
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

  describe 'form_submitted trigger' do
    let(:inbox) { create(:inbox, account: account) }
    let(:published_form) { create(:account_form, :published, account: account) }

    def form_submitted_graph(overrides = {})
      data = {
        'event_name' => 'form_submitted',
        'inbox_id' => inbox.id.to_s,
        'conditions' => [
          {
            'attribute_key' => 'account_form_id',
            'filter_operator' => 'equal_to',
            'values' => [published_form.id.to_s]
          }
        ]
      }.merge(overrides)
      {
        'nodes' => [
          { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => data },
          {
            'id' => 'action_1',
            'type' => 'action',
            'data' => { 'action_name' => 'add_label', 'action_params' => ['x'] }
          }
        ],
        'edges' => [{ 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'action_1' }],
        'settings' => {}
      }
    end

    it 'accepts a valid form_submitted trigger' do
      result = described_class.new(graph: form_submitted_graph, account: account).perform
      expect(result[:valid]).to be true
    end

    it 'rejects form_submitted trigger without inbox' do
      result = described_class.new(
        graph: form_submitted_graph('inbox_id' => ''),
        account: account
      ).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('requires an inbox')
    end

    it 'rejects form_submitted trigger without forms' do
      result = described_class.new(
        graph: form_submitted_graph('conditions' => []),
        account: account
      ).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('published form')
    end

    it 'rejects form_submitted trigger with draft form' do
      draft_form = create(:account_form, account: account)
      graph = form_submitted_graph(
        'conditions' => [
          {
            'attribute_key' => 'account_form_id',
            'filter_operator' => 'equal_to',
            'values' => [draft_form.id.to_s]
          }
        ]
      )
      result = described_class.new(graph: graph, account: account).perform
      expect(result[:valid]).to be false
      expect(Workflows::GraphValidationService.error_messages(result[:errors]).join).to include('unpublished form')
    end
  end
end
