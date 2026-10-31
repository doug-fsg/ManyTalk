# frozen_string_literal: true

class AiAttendant::HandoffService
  pattr_initialize [:conversation!, :summary!, :config!]

  def perform
    create_private_note
    open_conversation_if_needed
    assign_agent
    send_customer_message_if_unassigned
    persist_handoff_timestamp

    {
      assigned: conversation.assignee_id.present?,
      assignee_id: conversation.assignee_id
    }
  end

  private

  def create_private_note
    Messages::MessageBuilder.new(
      config.sender_user,
      conversation,
      { content: "[IA → Humano] #{summary}", private: true }
    ).perform
  end

  def open_conversation_if_needed
    conversation.update!(status: :open) unless conversation.open?
  end

  def assign_agent
    AutoAssignment::AgentAssignmentService.new(
      conversation: conversation,
      allowed_agent_ids: conversation.inbox.member_ids_with_assignment_capacity
    ).perform
    conversation.reload
  end

  def send_customer_message_if_unassigned
    return if conversation.assignee_id.present?
    return if config.handoff_customer_message.blank?

    Messages::MessageBuilder.new(
      config.sender_user,
      conversation,
      { content: config.handoff_customer_message, private: false }
    ).perform
  end

  def persist_handoff_timestamp
    contact = conversation.contact
    merged = (contact.custom_attributes || {}).merge('ai_handoff_at' => Time.current.iso8601)
    contact.update!(custom_attributes: merged)
  end
end
