# frozen_string_literal: true

module Workflows
  class RunScheduleJob < ApplicationJob
    queue_as :low

    def perform(schedule_id, run_token, cursor = 0)
      schedule = WorkflowSchedule.find_by(id: schedule_id)
      return if schedule.blank?
      return if schedule.run_token != run_token

      unless schedule.workflow&.active?
        schedule.finish_run!(status: 'failed')
        return
      end

      rows = page_for(schedule, cursor.to_i)
      if rows.empty?
        schedule.finish_run!(status: 'completed')
        return
      end

      contact_ids = rows.map(&:last)
      last_id = rows.last.first
      has_more = rows.size >= Constants::SCHEDULE_BATCH_SIZE

      ScheduleEnrollBatchJob.perform_later(schedule.id, run_token, contact_ids, !has_more)
      return unless has_more

      self.class.set(wait: Constants::SCHEDULE_BATCH_DELAY.seconds)
          .perform_later(schedule.id, run_token, last_id)
    end

    private

    def page_for(schedule, cursor)
      schedule.audience_scope
              .where('contact_pipeline_positions.id > ?', cursor)
              .order('contact_pipeline_positions.id')
              .limit(Constants::SCHEDULE_BATCH_SIZE)
              .pluck('contact_pipeline_positions.id', 'contact_pipeline_positions.contact_id')
    end
  end
end
