# frozen_string_literal: true

module Workflows
  class TimelineBuilder
    STATUSES = %w[completed running scheduled skipped failed pending].freeze

    def initialize(enrollment)
      @enrollment = enrollment
      @workflow = enrollment.workflow
      @executions_by_node = enrollment.workflow_step_executions.index_by(&:node_id)
      @nodes_by_id = (@workflow.graph['nodes'] || []).index_by { |n| n['id'] }
    end

    def build
      path = active_path_node_ids
      timeline = path.map { |node_id| build_step(node_id) }
      step_index = timeline.index { |s| s[:status] == 'running' } ||
                   timeline.index { |s| s[:status] == 'scheduled' } ||
                   timeline.rindex { |s| s[:status] == 'completed' } ||
                   0

      {
        timeline: timeline,
        step_index: step_index + 1,
        total_steps: timeline.size
      }
    end

    def step_counts
      meta = build
      { step_index: meta[:step_index], total_steps: meta[:total_steps] }
    end

    private

    def active_path_node_ids
      traversed = traversed_node_ids
      path = []
      node_id = @workflow.trigger_node&.dig('id')

      while node_id.present?
        path << node_id
        break if node_id == @enrollment.current_node_id

        node_id = next_on_path(node_id, traversed)
      end

      node_id = @enrollment.current_node_id
      while node_id.present? && !path.include?(node_id)
        path << node_id
        node_id = next_on_path(node_id, Set.new)
      end

      future_id = next_on_path(@enrollment.current_node_id, Set.new)
      while future_id.present? && !path.include?(future_id)
        path << future_id
        future_id = next_on_path(future_id, Set.new)
      end

      path.uniq
    end

    def traversed_node_ids
      @executions_by_node.each_with_object(Set.new) do |(node_id, execution), set|
        set.add(node_id) if execution.status.in?(%w[completed skipped failed running scheduled])
      end
    end

    def next_on_path(node_id, traversed)
      node = @nodes_by_id[node_id]
      return nil if node.blank?

      edges = @workflow.outgoing_edges(node_id)
      return nil if edges.empty?

      if Workflows::Constants::BRANCH_NODE_TYPES.include?(node['type'])
        pick_branch_edge(node_id, edges, traversed)
      else
        edges.first&.dig('target')
      end
    end

    def pick_branch_edge(node_id, edges, traversed)
      if node_id == @enrollment.current_node_id && @enrollment.reply_watch_active?
        edges.find { |e| e['sourceHandle'] == 'replied' }&.dig('target') ||
          edges.find { |e| e['sourceHandle'] == 'timeout' }&.dig('target')
      elsif node_id == @enrollment.current_node_id && @enrollment.intent_watch_active?
        edges.find { |e| e['sourceHandle'] == 'intent_detected' }&.dig('target') ||
          edges.find { |e| e['sourceHandle'] == 'timeout' }&.dig('target')
      else
        edges.find do |edge|
          target = edge['target']
          traversed.include?(target) || downstream_includes_current?(target)
        end&.dig('target') || edges.first&.dig('target')
      end
    end

    def downstream_includes_current?(node_id)
      return false if node_id.blank?

      queue = [node_id]
      visited = Set.new

      while queue.any?
        current = queue.shift
        next if visited.include?(current)

        visited.add(current)
        return true if current == @enrollment.current_node_id

        @workflow.outgoing_edges(current).each do |edge|
          queue << edge['target']
        end
      end

      false
    end

    def build_step(node_id)
      node = @nodes_by_id[node_id] || {}
      execution = @executions_by_node[node_id]
      status = resolve_status(node_id, execution)

      {
        node_id: node_id,
        label: Workflows::NodeLabel.for_node(node),
        type: node['type'],
        node_type: node['type'],
        status: status,
        executed_at: execution&.executed_at,
        scheduled_at: scheduled_at_for(node_id, execution, status),
        branch: branch_hint(node_id, status),
        error_message: status == 'failed' ? execution&.error_message : nil,
        action_details: Workflows::NodeLabel.action_details(node)
      }
    end

    def resolve_status(node_id, execution)
      if execution&.status == 'failed'
        'failed'
      elsif execution&.status == 'skipped'
        'skipped'
      elsif execution&.status == 'completed'
        'completed'
      elsif node_id == @enrollment.current_node_id
        current_node_status
      elsif execution&.status == 'scheduled'
        'scheduled'
      elsif execution&.status == 'running'
        'running'
      elsif execution.present?
        execution.status
      else
        'pending'
      end
    end

    def current_node_status
      case @enrollment.status
      when 'waiting' then 'running'
      when 'paused' then 'scheduled'
      else 'running'
      end
    end

    def scheduled_at_for(node_id, execution, status)
      return execution.scheduled_at if execution&.scheduled_at.present?
      return @enrollment.resume_at if node_id == @enrollment.current_node_id && @enrollment.resume_at.present?

      reply_watch = (@enrollment.context || {})['reply_watch']
      return Time.zone.parse(reply_watch['deadline_at']) if node_id == reply_watch&.dig('node_id') && status == 'running'

      intent_watch = (@enrollment.context || {})['intent_watch']
      return Time.zone.parse(intent_watch['deadline_at']) if node_id == intent_watch&.dig('node_id') && status == 'running'

      nil
    end

    def branch_hint(node_id, status)
      return 'awaiting' if node_id == @enrollment.current_node_id && @enrollment.reply_watch_active? && status == 'running'
      return 'awaiting' if node_id == @enrollment.current_node_id && @enrollment.intent_watch_active? && status == 'running'

      nil
    end
  end
end
