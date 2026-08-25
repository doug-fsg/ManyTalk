# frozen_string_literal: true

module Workflows
  class ActivationService
    PAUSE_REASON = 'workflow_inactive'

    def pause_in_progress!(workflow)
      control = EnrollmentControlService.new
      workflow.workflow_enrollments.in_progress.where(status: %w[active waiting]).find_each do |enrollment|
        control.pause(enrollment: enrollment, user: nil, reason: PAUSE_REASON)
      end
    end

    def resume_inactive!(workflow)
      control = EnrollmentControlService.new
      workflow.workflow_enrollments.paused.where(pause_reason: PAUSE_REASON).find_each do |enrollment|
        control.resume(enrollment: enrollment, user: nil)
      end
    end
  end
end
