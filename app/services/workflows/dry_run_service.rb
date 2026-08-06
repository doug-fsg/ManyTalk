# frozen_string_literal: true

module Workflows
  # Traverses a workflow graph without side effects.
  # Supports interactive decisions: skip waits, pick IF branches, pick reply outcomes.
  class DryRunService
    MAX_TRACE_NODES = 80

    def initialize(workflow:, conversation: nil, decisions: [], auto_skip_waits: false)
      @workflow = workflow
      @conversation = conversation
      @decisions = normalize_decisions(decisions)
      @auto_skip_waits = auto_skip_waits
      @paused_at = nil
    end

    def perform
      trace = []
      start_id = @workflow.trigger_node&.dig('id')
      return { trace: trace, truncated: false, error: 'no_trigger', paused_at: nil, completed: false } if start_id.blank?

      traverse(start_id, trace)
      truncated = trace.length >= MAX_TRACE_NODES

      {
        trace: trace,
        truncated: truncated,
        paused_at: @paused_at,
        completed: @paused_at.nil? && truncated == false
      }
    end

    private

    def normalize_decisions(decisions)
      Array(decisions).each_with_object({}) do |entry, map|
        node_id, branch = extract_decision(entry)
        next if node_id.blank?

        map[node_id.to_s] = branch.to_s
      end
    end

    def extract_decision(entry)
      hash = case entry
             when ActionController::Parameters
               entry.to_unsafe_h
             when Hash
               entry
             else
               {}
             end

      node_id = hash['node_id'] || hash[:node_id]
      branch = hash['branch'] || hash[:branch]
      [node_id, branch]
    end

    def decision_for(node_id)
      @decisions[node_id.to_s]
    end

    def traverse(node_id, trace, depth = 0)
      return if node_id.blank? || depth >= MAX_TRACE_NODES || trace.length >= MAX_TRACE_NODES

      node = @workflow.find_node(node_id)
      return if node.blank?

      step = build_step(node)
      trace << step

      case node['type']
      when 'trigger', 'action', 'ai_outreach', 'ai_conversation_analysis'
        traverse(@workflow.next_node_id(node_id), trace, depth + 1)

      when 'wait'
        handle_wait(node, step, node_id, trace, depth)

      when 'wait_for_reply'
        handle_wait_for_reply(node, step, node_id, trace, depth)

      when 'condition'
        handle_condition(node, step, node_id, trace, depth)
      end
    end

    def handle_wait(node, step, node_id, trace, depth)
      branch = decision_for(node_id)
      branch = 'skip' if branch.blank? && @auto_skip_waits

      if branch == 'skip'
        apply_branch(step, 'skip')
        traverse(@workflow.next_node_id(node_id), trace, depth + 1)
      else
        pause_at(node, step, [{ branch: 'skip' }])
      end
    end

    def handle_wait_for_reply(node, step, node_id, trace, depth)
      branch = decision_for(node_id)
      if branch.in?(%w[replied timeout])
        apply_branch(step, branch)
        next_id = @workflow.next_node_id(node_id, source_handle: branch)
        traverse(next_id, trace, depth + 1)
      else
        pause_at(node, step, [{ branch: 'replied' }, { branch: 'timeout' }])
      end
    end

    def handle_condition(node, step, node_id, trace, depth)
      result = evaluate_condition(node)

      if !result.nil?
        handle = result ? 'true' : 'false'
        apply_branch(step, handle)
        traverse(@workflow.next_node_id(node_id, source_handle: handle), trace, depth + 1)
        return
      end

      branch = decision_for(node_id)
      if branch.in?(%w[true false])
        apply_branch(step, branch)
        traverse(@workflow.next_node_id(node_id, source_handle: branch), trace, depth + 1)
      else
        pause_at(node, step, [{ branch: 'true' }, { branch: 'false' }])
      end
    end

    def pause_at(node, step, choices)
      step[:stops] = true
      step[:pending] = true
      return if @paused_at.present?

      @paused_at = {
        node_id: node['id'],
        type: node['type'],
        label: step[:label],
        choices: choices
      }
    end

    def apply_branch(step, branch)
      step[:stops] = false
      step[:pending] = false
      step[:simulated_branch] = branch
      step[:branch_taken] = branch
    end

    def build_step(node)
      data = node['data'] || {}
      {
        node_id: node['id'],
        type: node['type'],
        label: data['label'].presence || node['type'],
        description: describe(node),
        stops: false,
        pending: false,
        simulated_branch: nil,
        condition_result: nil,
        branch_taken: nil
      }
    end

    def describe(node)
      data = node['data'] || {}
      case node['type']
      when 'trigger'
        data['event_name'] || 'trigger'
      when 'action'
        items = Workflows::ActionNodeData.items(data)
        return data['action_name'].to_s if items.blank?

        items.map do |item|
          [item['action_name'], Array(item['action_params']).first].compact.join(': ')
        end.join(' → ')
      when 'wait'
        "#{data['duration']} #{data['unit']}"
      when 'wait_for_reply'
        "#{data['duration']} #{data['unit']} · #{data['wait_responder'] || 'contact'}"
      when 'condition'
        count = (data['conditions'] || []).length
        count.positive? ? "#{count} condição(ões)" : 'condição'
      when 'ai_outreach'
        data['objective_preset'] || 'ai_outreach'
      when 'ai_conversation_analysis'
        data['analysis_types']&.first || 'analysis'
      else
        node['type']
      end
    end

    def evaluate_condition(node)
      return nil if @conversation.blank?

      data = node['data'] || {}
      ConditionsEvaluator.new(
        account: @workflow.account,
        conversation: @conversation,
        conditions: data['conditions'] || []
      ).match?
    rescue StandardError
      nil
    end
  end
end
