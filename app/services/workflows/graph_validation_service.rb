# frozen_string_literal: true

require 'set'

module Workflows
  class GraphValidationService
    pattr_initialize [:graph!, :account]

    def perform
      @errors = []
      validate_size
      validate_structure
      validate_trigger
      validate_nodes
      validate_edges
      validate_reachability
      validate_acyclic
      validate_limits

      { valid: @errors.empty?, errors: @errors }
    end

    def self.error_messages(errors)
      Array(errors).map { |error| error.is_a?(Hash) ? error[:message] : error.to_s }
    end

    private

    def nodes
      @nodes ||= graph['nodes'].presence || []
    end

    def edges
      @edges ||= graph['edges'].presence || []
    end

    def add_error(message, node_id: nil)
      @errors << { message: message, node_id: node_id }
    end

    def validate_size
      return if graph.to_json.bytesize <= Constants::MAX_GRAPH_BYTES

      add_error("Graph exceeds maximum size of #{Constants::MAX_GRAPH_BYTES} bytes")
    end

    def validate_structure
      add_error('Graph must include nodes array') unless graph['nodes'].is_a?(Array)
      add_error('Graph must include edges array') unless graph['edges'].is_a?(Array)
    end

    def validate_trigger
      triggers = nodes.select { |n| n['type'] == 'trigger' }
      add_error('Graph must have exactly one trigger node') if triggers.size != 1
    end

    def validate_nodes
      node_ids = []
      nodes.each do |node|
        add_error('Each node must have an id') if node['id'].blank?
        add_error("Duplicate node id: #{node['id']}", node_id: node['id']) if node_ids.include?(node['id'])

        node_ids << node['id']
        validate_node(node)
      end
    end

    def validate_node(node)
      type = node['type']
      unless Constants::NODE_TYPES.include?(type)
        add_error("Invalid node type: #{type}", node_id: node['id'])
        return
      end

      data = node['data'] || {}
      case type
      when 'trigger'
        validate_trigger_node(data, node)
      when 'wait'
        validate_wait_node(data, node)
      when 'wait_for_reply'
        validate_wait_for_reply_node(data, node)
      when 'condition'
        validate_condition_node(data, node)
      when 'action'
        validate_action_node(data, node)
      when 'ai_outreach'
        validate_ai_outreach_node(data, node)
      when 'ai_conversation_analysis'
        validate_ai_conversation_analysis_node(data, node)
      end
    end

    def validate_trigger_node(data, node)
      event = data['event_name']
      return if Constants::ALLOWED_TRIGGER_EVENTS.include?(event)

      add_error("Invalid trigger event: #{event}", node_id: node['id'])
    end

    def validate_wait_node(data, node)
      validate_wait_duration(data, node)
    end

    def validate_wait_for_reply_node(data, node)
      validate_wait_duration(data, node)
      responder = data['wait_responder'].presence || 'contact'
      return if Workflows::Constants::WAIT_RESPONDERS.include?(responder)

      add_error("Invalid wait responder: #{responder}", node_id: node['id'])
    end

    def validate_wait_duration(data, node)
      unit = data['unit']
      duration = data['duration'].to_i
      limits = Constants::WAIT_LIMITS[unit]
      add_error("Invalid wait unit: #{unit}", node_id: node['id']) unless limits
      return unless limits

      if duration < limits[:min] || duration > limits[:max]
        add_error("Wait duration must be between #{limits[:min]} and #{limits[:max]} #{unit}", node_id: node['id'])
      end
    end

    def validate_condition_node(data, node)
      conditions = data['conditions'] || []
      return if conditions.blank?

      rule = ConditionRuleAdapter.new(account: account, conditions: conditions, id: 0)
      return if AutomationRules::ConditionValidationService.new(rule).perform

      add_error('Condition node has invalid filter configuration', node_id: node['id'])
    end

    def validate_action_node(data, node)
      name = data['action_name']
      unless Constants::ALLOWED_ACTION_NAMES.include?(name)
        add_error("Invalid action: #{name}", node_id: node['id'])
        return
      end

      validate_action_params(name, data, node)
    end

    def validate_action_params(name, data, node)
      case name
      when 'send_whatsapp_external'
        params = data['action_params'] || []
        add_error('WhatsApp action requires an inbox', node_id: node['id']) if params[0].blank?
        if params[1].blank?
          add_error('WhatsApp action requires a phone number', node_id: node['id'])
        elsif !Workflows::PhoneNormalizer.valid?(params[1])
          add_error('WhatsApp action phone number is invalid', node_id: node['id'])
        end
        validate_external_whatsapp_inbox(params[0], node) if params[0].present?
      end
    end

    def validate_external_whatsapp_inbox(inbox_id, node)
      inbox = account.inboxes.find_by(id: inbox_id)
      add_error('WhatsApp action inbox not found', node_id: node['id']) if inbox.blank?
      return if inbox.blank?

      return if inbox.external_whatsapp_capable?

      add_error('WhatsApp action requires a WhatsApp or WhatsApp Web (API) inbox', node_id: node['id'])
    end

    def validate_ai_outreach_node(data, node)
      unless account&.feature_enabled?('inteligencia_artificial')
        add_error('AI outreach requires the inteligencia_artificial feature', node_id: node['id'])
        return
      end

      objective = data['objective_preset'].presence || 'reengagement'
      unless Constants::AI_OUTREACH_OBJECTIVES.include?(objective)
        add_error("Invalid AI objective preset: #{objective}", node_id: node['id'])
      end

      tone = data['tone_preset'].presence || 'friendly'
      unless Constants::AI_OUTREACH_TONES.include?(tone)
        add_error("Invalid AI tone preset: #{tone}", node_id: node['id'])
      end

      language = data['language'].presence || 'client'
      unless Constants::AI_LANGUAGES.include?(language)
        add_error("Invalid AI language: #{language}", node_id: node['id'])
      end

      prompt = data['prompt'].to_s
      if prompt.blank?
        add_error('AI outreach node requires a prompt', node_id: node['id'])
      elsif prompt.length > Constants::MAX_AI_OUTREACH_PROMPT_LENGTH
        add_error(
          "AI prompt exceeds maximum length of #{Constants::MAX_AI_OUTREACH_PROMPT_LENGTH} characters",
          node_id: node['id']
        )
      end
    end

    def validate_ai_conversation_analysis_node(data, node)
      unless account&.feature_enabled?('inteligencia_artificial')
        add_error('AI conversation analysis requires the inteligencia_artificial feature', node_id: node['id'])
        return
      end

      types = Array(data['analysis_types'])
      invalid = types.reject { |t| Constants::AI_ANALYSIS_TYPES.include?(t) }
      invalid.each do |t|
        add_error("Invalid analysis type: #{t}", node_id: node['id'])
      end

      destination = data['output_destination'].presence || 'private_note'
      unless Constants::AI_ANALYSIS_OUTPUT_DESTINATIONS.include?(destination)
        add_error("Invalid output destination: #{destination}", node_id: node['id'])
      end

      if destination == 'whatsapp_external'
        if data['whatsapp_inbox_id'].blank?
          add_error('AI analysis whatsapp_external requires whatsapp_inbox_id', node_id: node['id'])
        else
          validate_external_whatsapp_inbox(data['whatsapp_inbox_id'], node)
        end
        if data['whatsapp_phone'].blank?
          add_error('AI analysis whatsapp_external requires whatsapp_phone', node_id: node['id'])
        elsif !Workflows::PhoneNormalizer.valid?(data['whatsapp_phone'])
          add_error('AI analysis whatsapp_external phone number is invalid', node_id: node['id'])
        end
      end
    end

    def validate_edges
      node_ids = nodes.map { |n| n['id'] }
      edges.each do |edge|
        add_error('Edge missing source or target') if edge['source'].blank? || edge['target'].blank?
        add_error("Edge references unknown node: #{edge['source']}", node_id: edge['source']) unless node_ids.include?(edge['source'])
        add_error("Edge references unknown node: #{edge['target']}", node_id: edge['target']) unless node_ids.include?(edge['target'])

        target_node = nodes.find { |n| n['id'] == edge['target'] }
        if target_node&.dig('type') == 'trigger'
          add_error('Edges cannot connect into the trigger node', node_id: edge['target'])
        end

        source_node = nodes.find { |n| n['id'] == edge['source'] }
        next if source_node.blank?

        validate_branch_edge(source_node, edge)
      end

      validate_branch_nodes_have_outbound_edges
    end

    def validate_branch_edge(source_node, edge)
      case source_node['type']
      when 'condition'
        handle = edge['sourceHandle']
        unless Constants::CONDITION_SOURCE_HANDLES.include?(handle)
          add_error('Condition edges must use sourceHandle true or false', node_id: source_node['id'])
        end
      when 'wait_for_reply'
        handle = edge['sourceHandle']
        unless Constants::REPLY_WATCH_SOURCE_HANDLES.include?(handle)
          add_error('Wait for reply edges must use sourceHandle replied or timeout', node_id: source_node['id'])
        end
      end
    end

    def validate_branch_nodes_have_outbound_edges
      nodes.each do |node|
        next unless Constants::BRANCH_NODE_TYPES.include?(node['type'])

        outbound = edges.select { |e| e['source'] == node['id'] }
        if outbound.empty?
          add_error("Node #{node['id']} must have at least one outbound connection", node_id: node['id'])
        end
      end
    end

    def validate_reachability
      trigger = nodes.find { |n| n['type'] == 'trigger' }
      return if trigger.blank?

      reachable = reachable_from(trigger['id'])
      nodes.each do |node|
        next if node['type'] == 'trigger'

        unless reachable.include?(node['id'])
          add_error("Node #{node['id']} is not reachable from trigger", node_id: node['id'])
        end
      end
    end

    def reachable_from(start_id)
      visited = Set.new
      queue = [start_id]
      while queue.any?
        current = queue.shift
        next if visited.include?(current)

        visited.add(current)
        edges.select { |e| e['source'] == current }.each { |e| queue << e['target'] }
      end
      visited
    end

    def validate_acyclic
      trigger = nodes.find { |n| n['type'] == 'trigger' }
      return if trigger.blank?

      return unless cycle_detected?(trigger['id'], Set.new, Set.new)

      add_error('Graph contains a cycle')
    end

    def cycle_detected?(node_id, visiting, visited)
      return true if visiting.include?(node_id)

      return false if visited.include?(node_id)

      visiting.add(node_id)
      edges.select { |e| e['source'] == node_id }.each do |edge|
        return true if cycle_detected?(edge['target'], visiting, visited)
      end
      visiting.delete(node_id)
      visited.add(node_id)
      false
    end

    def validate_limits
      send_count = nodes.count { |n| n['type'] == 'action' && n.dig('data', 'action_name') == 'send_message' }
      if send_count > Constants::MAX_SEND_MESSAGE_ACTIONS
        add_error("Maximum #{Constants::MAX_SEND_MESSAGE_ACTIONS} send_message actions allowed")
      end

      wait_count = nodes.count { |n| %w[wait wait_for_reply].include?(n['type']) }
      add_error("Maximum #{Constants::MAX_WAIT_NODES} wait nodes allowed") if wait_count > Constants::MAX_WAIT_NODES
    end
  end
end
