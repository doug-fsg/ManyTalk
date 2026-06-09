# frozen_string_literal: true

module Workflows
  class EnrollmentRebindService
    def rebind(enrollment:, new_conversation:, user:)
      return { error: :invalid_conversation } if new_conversation.contact_id != enrollment.contact_id
      return { error: :conversation_not_open } unless new_conversation.open?

      old_conversation_id = enrollment.conversation_id

      enrollment.with_lock do
        history = (enrollment.context || {})['rebind_history'] || []
        history << {
          'from_conversation_id' => old_conversation_id,
          'to_conversation_id' => new_conversation.id,
          'rebound_by_id' => user&.id,
          'rebound_at' => Time.current.iso8601(6)
        }

        enrollment.update!(
          conversation_id: new_conversation.id,
          context: (enrollment.context || {}).merge('rebind_history' => history)
        )
      end

      EnrollmentBroadcaster.updated(enrollment.reload)
      { enrollment: enrollment, old_conversation_id: old_conversation_id }
    end
  end
end
