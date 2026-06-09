# frozen_string_literal: true

module Workflows
  module EnrollmentMetrics
    module_function

    def contact_replied_during?(enrollment)
      return false if enrollment.started_at.blank?

      enrollment.conversation.messages.incoming
                .where('messages.created_at >= ?', enrollment.started_at)
                .exists?
    end
  end
end
