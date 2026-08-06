# frozen_string_literal: true

module Workflows
  class EnrollmentPayloadBuilder
    def self.for_action_cable(enrollment)
      workflow = enrollment.workflow
      current_node = workflow.find_node(enrollment.current_node_id)
      counts = TimelineBuilder.new(enrollment).step_counts

      {
        enrollment_id: enrollment.id,
        conversation_id: enrollment.conversation_id,
        workflow_id: enrollment.workflow_id,
        workflow_name: workflow.name,
        status: enrollment.status,
        current_node_id: enrollment.current_node_id,
        current_node_label: Workflows::NodeLabel.for_node(current_node),
        current_node_type: current_node&.dig('type'),
        step_index: counts[:step_index],
        total_steps: counts[:total_steps]
      }
    end
  end
end
