# frozen_string_literal: true

module Workflows
  class JobScheduler
    class << self
      def schedule(enrollment, node_id, delay)
        job = Workflows::StepJob.set(wait: delay).perform_later(enrollment.id, node_id)
        execution = enrollment.workflow_step_executions.find_or_initialize_by(node_id: node_id)
        execution.update!(
          status: 'scheduled',
          scheduled_at: Time.current + delay,
          job_id: job_reference_id(job)
        )
        job
      end

      def cancel_pending!(enrollment)
        enrollment.workflow_step_executions.where(status: 'scheduled').find_each do |execution|
          cancel_sidekiq_job(execution.job_id) if execution.job_id.present?
        end
      end

      def remaining_delay(execution)
        return 0.seconds unless execution&.scheduled_at

        delay = execution.scheduled_at - Time.current
        [delay, 1.second].max
      end

      private

      def job_reference_id(job)
        return if job.blank?

        job.provider_job_id || job.job_id
      end

      def cancel_sidekiq_job(job_id)
        scheduled_set = Sidekiq::ScheduledSet.new
        job = scheduled_set.find_job(job_id)
        job&.delete
      rescue StandardError => e
        Rails.logger.warn("Failed to cancel Sidekiq job #{job_id}: #{e.message}")
      end
    end
  end
end
