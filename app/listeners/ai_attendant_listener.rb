# frozen_string_literal: true

class AiAttendantListener < BaseListener
  def message_created(event)
    message, _account = extract_message_and_account(event)
    return if message.blank?

    eligibility = AiAttendant::Eligibility.call(message: message)
    return unless eligibility[:eligible]

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
end
