# frozen_string_literal: true

module Workflows
  class DueSchedulesTickJob < ApplicationJob
    queue_as :scheduled_jobs

    def perform
      claimed = WorkflowSchedule.claim_due!(
        now: Time.current,
        limit: Constants::SCHEDULE_DUE_CLAIM_LIMIT
      )
      claimed.each do |schedule|
        RunScheduleJob.perform_later(schedule.id, schedule.run_token, 0)
      end
    end
  end
end
