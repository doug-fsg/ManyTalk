# frozen_string_literal: true

module Workflows
  class IntentClassificationJob < ApplicationJob
    queue_as :critical

    retry_on StandardError, wait: 3.seconds, attempts: 2
    discard_on ActiveJob::DeserializationError

    def perform(enrollment_id, message_id)
      enrollment = WorkflowEnrollment.find_by(id: enrollment_id)
      return unless enrollment

      message = Message.find_by(id: message_id)

      enrollment.with_lock do
        return unless enrollment.intent_watch_active?
        return if already_processed?(enrollment, message_id)
        return if enrollment.intent_watch_classification_in_flight?

        return if message && enrollment.intent_watch_baseline_at &&
                  message.created_at < enrollment.intent_watch_baseline_at

        content = message&.content.to_s
        prefilter = Workflows::IntentMessagePrefilter.new(
          content,
          seen_normalized: enrollment.seen_normalized_content
        )

        if prefilter.skip?
          enrollment.record_intent_classification!(
            message_id: message_id,
            matched: false,
            skipped: true,
            reason: prefilter.skip_reason.to_s
          )
          enrollment.add_seen_normalized!(prefilter.normalized)
          log_skip(enrollment_id, prefilter.skip_reason)
          return
        end

        enrollment.set_intent_classification_in_flight!(true)
      end

      result = Workflows::AiWaitForIntentService.new(enrollment, message).classify!

      enrollment.with_lock do
        return unless enrollment.intent_watch_active?

        enrollment.record_intent_classification!(
          message_id: message_id,
          matched: result[:matched]
        )
        enrollment.add_seen_normalized!(
          Workflows::IntentMessagePrefilter.new(message&.content.to_s).normalized
        )

        if result[:matched]
          Workflows::OrchestratorService.on_intent_detected(enrollment)
        end
      end
    end

    private

    def already_processed?(enrollment, message_id)
      enrollment.last_classified_message_id == message_id
    end

    def log_skip(enrollment_id, reason)
      Rails.logger.info(
        "[IntentClassificationJob] enrollment=#{enrollment_id} " \
        "intent_classify.result=skipped intent_classify.skip_reason=#{reason} " \
        'intent_classify.prefilter_saved=true'
      )
    end
  end
end
