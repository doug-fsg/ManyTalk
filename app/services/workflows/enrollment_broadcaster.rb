# frozen_string_literal: true

module Workflows
  class EnrollmentBroadcaster
    class << self
      def updated(enrollment)
        enrollment.reload
        Rails.logger.info("Workflow enrollment #{enrollment.id} updated to #{enrollment.status}")

        Rails.configuration.dispatcher.dispatch(
          Events::Types::WORKFLOW_ENROLLMENT_UPDATED,
          Time.zone.now,
          enrollment: enrollment,
          conversation: enrollment.conversation,
          account: enrollment.account
        )
      end
    end
  end
end
