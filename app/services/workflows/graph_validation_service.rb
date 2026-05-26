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

    private

    def nodes
      @nodes ||= graph['nodes'].presence || []
    end

    def edges
      @edges ||= graph['edges'].presence || []
    end

    def validate_size
      return if graph.to_json.bytesize <= Constants::MAX_GRAPH_BYTES

      @errors << "Graph exceeds maximum size of #{Constants::MAX_GRAPH_BYTES} bytes"
    end

    def validate_structure
      @errors << 'Graph must include nodes array' unless graph['nodes'].is_a?(Array)
      @errors << 'Graph must include edges array' unless graph['edges'].is_a?(Array)
    end

    def validate_trigger
      triggers = nodes.select { |n| n['type'] == 'trigger' }
      @errors << 'Graph must have exactly one trigger node' if triggers.size != 1
    end

    def validate_nodes
      node_ids = []
      nodes.each do |node|
        @errors << 'Each node must have an id' if node['id'].blank?
        @errors << "Duplicate node id: #{node['id']}" if node_ids.include?(node['id'])

        node_ids << node['id']
        validate_node(node)
      end
    end

    def validate_node(node)
      type = node['type']
      unless Constants::NODE_TYPES.include?(type)
        @errors << "Invalid node type: #{type}"
        return
      end

      data = node['data'] || {}
      case type
      when 'trigger'
        validate_trigger_node(data)
      when 'wait'
        validate_wait_node(data)
      when 'condition'
        validate_condition_node(data)
      when 'action'
        validate_action_node(data)
      end
    end

    def validate_trigger_node(data)
      event = data['event_name']
      @errors << "Invalid trigger event: #{event}" unless Constants::ALLOWED_TRIGGER_EVENTS.include?(event)
    end

    def validate_wait_node(data)
      unit = data['unit']
      duration = data['duration'].to_i
      limits = Constants::WAIT_LIMITS[unit]
      @errors << "Invalid wait unit: #{unit}" unless limits
      return unless limits

      @errors << "Wait duration must be between #{limits[:min]} and #{limits[:max]} #{unit}" if duration < limits[:min] || duration > limits[:max]
    end

    def validate_condition_node(data)
      conditions = data['conditions'] || []
      return if conditions.blank?

      rule = ConditionRuleAdapter.new(account: account, conditions: conditions, id: 0)
      return if AutomationRules::ConditionValidationService.new(rule).perform

      @errors << 'Condition node has invalid filter configuration'
    end

    def validate_action_node(data)
      name = data['action_name']
      @errors << "Invalid action: #{name}" unless Constants::ALLOWED_ACTION_NAMES.include?(name)
    end

    def validate_edges
      node_ids = nodes.map { |n| n['id'] }
      edges.each do |edge|
        @errors << 'Edge missing source or target' if edge['source'].blank? || edge['target'].blank?
        @errors << "Edge references unknown node: #{edge['source']}" unless node_ids.include?(edge['source'])
        @errors << "Edge references unknown node: #{edge['target']}" unless node_ids.include?(edge['target'])

        target_node = nodes.find { |n| n['id'] == edge['target'] }
        if target_node&.dig('type') == 'trigger'
          @errors << 'Edges cannot connect into the trigger node'
        end

        source_node = nodes.find { |n| n['id'] == edge['source'] }
        next unless source_node&.dig('type') == 'condition'

        handle = edge['sourceHandle']
        @errors << 'Condition edges must use sourceHandle true or false' unless %w[true false].include?(handle)
      end
    end

    def validate_reachability
      trigger = nodes.find { |n| n['type'] == 'trigger' }
      return if trigger.blank?

      reachable = reachable_from(trigger['id'])
      nodes.each do |node|
        next if node['type'] == 'trigger'

        @errors << "Node #{node['id']} is not reachable from trigger" unless reachable.include?(node['id'])
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

      @errors << 'Graph contains a cycle'
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
      @errors << "Maximum #{Constants::MAX_SEND_MESSAGE_ACTIONS} send_message actions allowed" if send_count > Constants::MAX_SEND_MESSAGE_ACTIONS

      wait_count = nodes.count { |n| n['type'] == 'wait' }
      @errors << "Maximum #{Constants::MAX_WAIT_NODES} wait nodes allowed" if wait_count > Constants::MAX_WAIT_NODES
    end
  end
end
