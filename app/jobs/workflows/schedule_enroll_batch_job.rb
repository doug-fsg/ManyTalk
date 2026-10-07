# frozen_string_literal: true

module Workflows
  class ScheduleEnrollBatchJob < ApplicationJob
    queue_as :low

    def perform(schedule_id, run_token, contact_ids, final_batch = false)
      schedule = WorkflowSchedule.find_by(id: schedule_id)
      return if schedule.blank?
      return if schedule.run_token != run_token

      counts = { enrolled: 0, skipped: 0, failed: 0 }
      Array(contact_ids).each do |contact_id|
        result = ScheduleEnrollContactService.new(schedule: schedule, contact_id: contact_id).perform
        bucket = case result
                 when :enrolled then :enrolled
                 when :failed then :failed
                 else :skipped
                 end
        counts[bucket] += 1
      rescue StandardError => e
        counts[:failed] += 1
        Rails.logger.error(
          "[WorkflowSchedule] enroll failed schedule=#{schedule_id} contact=#{contact_id} error=#{e.class}: #{e.message}"
        )
      end

      schedule.increment_run_stat!('enrolled', counts[:enrolled])
      schedule.increment_run_stat!('skipped', counts[:skipped])
      schedule.increment_run_stat!('failed', counts[:failed])
      schedule.finish_run!(status: 'completed') if final_batch
    end
  end
end
