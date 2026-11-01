# frozen_string_literal: true

class AiAttendant::HandoffService
  DEFAULT_CUSTOMER_MESSAGE = 'Vou te encaminhar para um atendente. Se ninguém estiver disponível agora, a conversa fica na fila.'

  pattr_initialize [:conversation!, :summary!, :config!, { customer_notice: nil }]

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
      config.message_sender,
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

    Messages::MessageBuilder.new(
      config.message_sender,
      conversation,
      { content: public_handoff_text, private: false }
    ).perform
  end

  def public_handoff_text
    customer_notice.presence || config.handoff_customer_message.presence || DEFAULT_CUSTOMER_MESSAGE
  end

  def persist_handoff_timestamp
    AiAttendant::ConversationState.mark_handoff!(conversation)
  end
end
