# frozen_string_literal: true

module Workflows
  class KanbanActionInbox
    def self.id_from(workflow)
      new(workflow).id
    end

    def initialize(workflow)
      @workflow = workflow
    end

    def id
      configured_ids.each do |inbox_id|
        return inbox_id if inbox_id.positive?
      end
      nil
    end

    private

    def configured_ids
      nodes = @workflow.graph['nodes'] || []
      nodes.flat_map { |node| inbox_ids_from(node) }
    end

    def inbox_ids_from(node)
      data = node['data'] || {}
      case node['type']
      when 'action'
        ActionNodeData.items(data).filter_map { |item| inbox_id_from_action(item) }
      when 'ai_outreach'
        [data['inbox_id'].to_i].reject(&:zero?)
      else
        []
      end
    end

    def inbox_id_from_action(item)
      inbox_id = item['inbox_id']
      inbox_id = item.dig('action_params', 0) if inbox_id.blank? && item['action_name'] == 'send_whatsapp_external'
      return if inbox_id.blank?

      inbox_id.to_i
    end
  end
end
