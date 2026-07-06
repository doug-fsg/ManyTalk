# frozen_string_literal: true

module Workflows
  class DestroyService
    def initialize(workflow:)
      @workflow = workflow
    end

    def perform
      workflow.transaction do
        enrollment_scope = WorkflowEnrollment.where(workflow_id: workflow.id)

        enrollment_scope.find_each do |enrollment|
          enrollment.cancel!('workflow_deleted') if enrollment.status.in?(%w[active waiting paused])
          JobScheduler.cancel_pending!(enrollment)
        end

        enrollment_ids = enrollment_scope.pluck(:id)
        WorkflowStepExecution.where(workflow_enrollment_id: enrollment_ids).delete_all if enrollment_ids.any?
        # destroy_async na associação faz delete_all via proxy anular FKs em vez de apagar.
        enrollment_scope.delete_all

        workflow.delete
      end
    end

    private

    attr_reader :workflow
  end
end
