# frozen_string_literal: true

module Workflows
  class EnrollmentPresence
    def self.exists?(workflow, conversation)
      new(workflow, conversation).exists?
    end

    def initialize(workflow, conversation)
      @workflow = workflow
      @conversation = conversation
    end

    def exists?
      in_progress_on_conversation? ||
        contact_scoped_in_progress? ||
        contact_scope_blocks_any_in_progress? ||
        reenrollment_blocked?
    end

    private

    attr_reader :workflow, :conversation

    def in_progress_on_conversation?
      WorkflowEnrollment.in_progress.exists?(workflow_id: workflow.id, conversation_id: conversation.id)
    end

    def contact_scoped_in_progress?
      return false if conversation.contact_id.blank?

      WorkflowEnrollment.in_progress.exists?(
        workflow_id: workflow.id,
        contact_id: conversation.contact_id,
        enrollment_scope: 'contact'
      )
    end

    def contact_scope_blocks_any_in_progress?
      return false if conversation.contact_id.blank?
      return false if workflow.settings['enrollment_scope'] == 'conversation'

      WorkflowEnrollment.in_progress.exists?(workflow_id: workflow.id, contact_id: conversation.contact_id)
    end

    def reenrollment_blocked?
      contact_id = conversation.contact_id
      return false if contact_id.blank?

      past = WorkflowEnrollment.where(workflow_id: workflow.id, contact_id: contact_id)
                               .where(status: %w[completed cancelled])
      return false unless past.exists?
      return true unless workflow.settings['allow_reenrollment'] == true

      settings = workflow.settings
      if settings['reenrollment_on_cancel'] == false && past.exists?(status: 'cancelled')
        return true
      end

      min_days = settings['reenrollment_min_interval_days'].to_i
      if min_days.positive?
        last = past.order(updated_at: :desc).first
        return true if last && last.updated_at > min_days.days.ago
      end

      max_total = settings['max_enrollments_per_contact'].to_i
      if max_total.positive?
        total = WorkflowEnrollment.where(workflow_id: workflow.id, contact_id: contact_id).count
        return true if total >= max_total
      end

      false
    end
  end
end
