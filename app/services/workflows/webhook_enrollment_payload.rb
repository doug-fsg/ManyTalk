# frozen_string_literal: true

module Workflows
  class WebhookEnrollmentPayload
    MAX_ITEMS = 3

    def self.for(conversation)
      new(conversation).build
    end

    def initialize(conversation)
      @conversation = conversation
    end

    def build
      return inactive_payload unless @conversation.account.feature_enabled?('workflows')

      enrollments = WorkflowEnrollment.enrollments_for_conversation(@conversation)
                                      .includes(:workflow)
                                      .limit(MAX_ITEMS)
                                      .to_a
      return inactive_payload if enrollments.empty?

      {
        active: true,
        items: enrollments.map { |enrollment| item_for(enrollment) }
      }
    end

    private

    def inactive_payload
      { active: false }
    end

    def item_for(enrollment)
      workflow = enrollment.workflow
      node = workflow&.find_node(enrollment.current_node_id)

      {
        enrollment_id: enrollment.id,
        workflow_id: enrollment.workflow_id,
        name: workflow&.name,
        status: enrollment.status,
        step: step_label(node)
      }.compact
    end

    def step_label(node)
      return nil if node.blank?

      node.dig('data', 'label').presence || node['type']
    end
  end
end
