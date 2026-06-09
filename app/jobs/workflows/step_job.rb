# frozen_string_literal: true

module Workflows
  class StepJob < ApplicationJob
    queue_as :medium

    retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
    retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3

    def perform(enrollment_id, node_id)
      enrollment = WorkflowEnrollment.find_by(id: enrollment_id)
      return if enrollment.blank? || enrollment.paused? || enrollment.cancelled? || enrollment.completed?

      Workflows::OrchestratorService.on_step(enrollment_id: enrollment_id, node_id: node_id)
    rescue StandardError => e
      mark_failed(enrollment_id, node_id, e) if enrollment_id.present?
      raise e unless transient_error?(e)
    end

    private

    def transient_error?(error)
      error.is_a?(ActiveRecord::Deadlocked) || error.is_a?(ActiveRecord::LockWaitTimeout)
    end

    def mark_failed(enrollment_id, node_id, error)
      enrollment = WorkflowEnrollment.find_by(id: enrollment_id)
      return if enrollment.blank?

      execution = enrollment.workflow_step_executions.find_by(node_id: node_id)
      execution&.update!(status: 'failed', error_message: error.message, executed_at: Time.current)
    end
  end
end
