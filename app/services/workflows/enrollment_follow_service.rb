# frozen_string_literal: true

module Workflows
  class EnrollmentFollowService
    def self.follow_to_conversation!(conversation)
      return if conversation.blank? || conversation.contact_id.blank?
      return unless conversation.open?

      WorkflowEnrollment.in_progress
                        .where(contact_id: conversation.contact_id, enrollment_scope: 'contact')
                        .find_each { |enrollment| new.sync_to!(enrollment, conversation) }
    end

    def sync_to!(enrollment, conversation)
      return enrollment.conversation if skip_sync?(enrollment, conversation)

      result = EnrollmentRebindService.new.rebind(
        enrollment: enrollment,
        new_conversation: conversation,
        user: nil
      )
      result[:enrollment]&.reload&.conversation || enrollment.reload.conversation
    rescue ActiveRecord::RecordNotUnique
      enrollment.reload.conversation
    end

    def ensure_actionable_conversation!(enrollment)
      bound = enrollment.conversation
      bound&.reload
      return bound if bound&.open?
      return bound unless enrollment.enrollment_scope == 'contact'

      latest = enrollment.contact&.conversations&.open&.order(updated_at: :desc)&.first
      return bound if latest.blank?

      sync_to!(enrollment, latest)
    end

    private

    def skip_sync?(enrollment, conversation)
      enrollment.enrollment_scope != 'contact' ||
        conversation.blank? ||
        !conversation.open? ||
        conversation.contact_id != enrollment.contact_id ||
        enrollment.conversation_id == conversation.id
    end
  end
end
