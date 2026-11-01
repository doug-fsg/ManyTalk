# frozen_string_literal: true

class AiAttendantListener < BaseListener
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    return if conversation.blank?

    AiAttendant::ConversationState.clear_handoff!(conversation)
  end

  def conversation_updated(event)
    conversation = extract_conversation_and_account(event)[0]
    return if conversation.blank?
    return if conversation.assignee_id.present?
    return unless released_by_agent?(event)

    AiAttendant::ConversationState.clear_handoff!(conversation)
  end

  def message_created(event)
    message, _account = extract_message_and_account(event)
    return if message.blank?

    eligibility = AiAttendant::Eligibility.call(message: message)
    unless eligibility[:eligible]
      if AiAttendant::CustomerNotice.immediate?(eligibility[:reason])
        AiAttendant::CustomerNotice.deliver!(message: message, reason: eligibility[:reason])
      end
      return
    end

    config = AiAttendantConfig.for_inbox(message.inbox_id).find_by(account_id: message.account_id)
    debounce_seconds = config&.debounce_seconds || 5

    buffer = AiAttendant::MessageBuffer.new(
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      conversation_id: message.conversation_id
    )
    role = buffer.push(
      message_id: message.id,
      content: message.content,
      debounce_seconds: debounce_seconds
    )
    return unless role == :leader

    AiAttendant::ProcessMessageJob
      .set(wait: debounce_seconds.seconds)
      .perform_later(message.account_id, message.inbox_id, message.conversation_id, [message.id])
  end

  private

  def released_by_agent?(event)
    changes = event.data[:changed_attributes]
    return false unless changes.respond_to?(:[])

    assignee_change = changes['assignee_id'] || changes[:assignee_id]
    return false unless assignee_change.is_a?(Array)

    previous_assignee, current_assignee = assignee_change
    previous_assignee.present? && current_assignee.blank?
  end
end
