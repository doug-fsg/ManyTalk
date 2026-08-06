# frozen_string_literal: true

module Workflows
  class EnrollmentSummaryService
    MAX_CONVERSATION_IDS = 50

    def initialize(account:, user:, conversation_ids:)
      @account = account
      @user = user
      @requested_ids = Array(conversation_ids).map(&:to_i).uniq.first(MAX_CONVERSATION_IDS)
    end

    def build
      return { summaries: {} } if @requested_ids.empty?

      conversation_rows = resolve_conversations
      return { summaries: {} } if conversation_rows.empty?

      internal_ids = conversation_rows.map(&:first)
      contact_ids = conversation_rows.map(&:third).compact.uniq

      enrollments = fetch_enrollments(internal_ids, contact_ids)
      enrollment_by_internal_id = index_enrollments(enrollments, conversation_rows)

      summaries = {}
      conversation_rows.each do |internal_id, display_id, _contact_id|
        enrollment = enrollment_by_internal_id[internal_id]
        next if enrollment.blank?

        payload = summary_for(enrollment)
        summaries[internal_id] = payload if @requested_ids.include?(internal_id)
        summaries[display_id] = payload if @requested_ids.include?(display_id)
      end

      { summaries: summaries }
    end

    private

    def resolve_conversations
      @account.conversations
              .where(id: @requested_ids)
              .or(@account.conversations.where(display_id: @requested_ids))
              .distinct
              .pluck(:id, :display_id, :contact_id)
    end

    def fetch_enrollments(internal_ids, contact_ids)
      scope = @account.workflow_enrollments
                      .in_progress
                      .includes(:workflow, :workflow_step_executions)

      scope = scope.joins(:conversation).where(conversations: { inbox_id: assigned_inbox_ids }) unless administrator?

      by_conversation = scope.where(conversation_id: internal_ids)
      by_contact = contact_ids.any? ? scope.where(contact_id: contact_ids, enrollment_scope: 'contact') : scope.none

      by_conversation.or(by_contact).distinct.to_a
    end

    def index_enrollments(enrollments, conversation_rows)
      by_conversation_id = enrollments.index_by(&:conversation_id)
      by_contact_id = enrollments.select { |e| e.enrollment_scope == 'contact' }.index_by(&:contact_id)

      conversation_rows.each_with_object({}) do |(internal_id, _display_id, contact_id), result|
        result[internal_id] = by_conversation_id[internal_id] || by_contact_id[contact_id]
      end
    end

    def summary_for(enrollment)
      workflow = enrollment.workflow
      counts = TimelineBuilder.new(enrollment).step_counts
      current_node = workflow.find_node(enrollment.current_node_id)

      {
        enrollment_id: enrollment.id,
        workflow_id: enrollment.workflow_id,
        workflow_name: workflow.name,
        status: enrollment.status,
        current_node_label: Workflows::NodeLabel.for_node(current_node),
        current_node_type: current_node&.dig('type'),
        step_index: counts[:step_index],
        total_steps: counts[:total_steps]
      }
    end

    def assigned_inbox_ids
      @assigned_inbox_ids ||= @user.assigned_inboxes.where(account_id: @account.id).pluck(:id)
    end

    def administrator?
      @account.account_users.find_by(user_id: @user.id)&.administrator?
    end
  end
end
