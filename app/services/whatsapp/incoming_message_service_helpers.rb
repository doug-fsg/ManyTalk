module Whatsapp::IncomingMessageServiceHelpers
  def download_attachment_file(attachment_payload)
    Down.download(inbox.channel.media_url(attachment_payload[:id]), headers: inbox.channel.api_headers)
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def processed_params
    @processed_params ||= params
  end

  def account
    @account ||= inbox.account
  end

  def message_type
    messages_data&.first&.dig(:type)
  end

  def message_content(message)
    # TODO: map interactive messages back to button messages in chatwoot
    message.dig(:text, :body) ||
      message.dig(:button, :text) ||
      message.dig(:interactive, :button_reply, :title) ||
      message.dig(:interactive, :list_reply, :title) ||
      message.dig(:name, :formatted_name) ||
      message.dig(message_type.to_sym, :caption)
  end

  def file_content_type(file_type)
    return :image if %w[image sticker].include?(file_type)
    return :audio if %w[audio voice].include?(file_type)
    return :video if ['video'].include?(file_type)
    return :location if ['location'].include?(file_type)
    return :contact if ['contacts'].include?(file_type)

    :file
  end

  def unprocessable_message_type?(message_type)
    %w[reaction ephemeral unsupported request_welcome].include?(message_type)
  end

  def brazil_phone_number?(phone_number)
    phone_number.match(/^55/)
  end

  # ref: https://github.com/chatwoot/chatwoot/issues/5840
  # Brazil mobiles may arrive with or without the extra 9 after DDD.
  # Canonical with-9 form: 55 + DDD(2) + 9 + 8 digits = 13 digits.
  def normalised_brazil_mobile_number(phone_number)
    # DDD : Area codes in Brazil are popularly known as "DDD codes" (códigos DDD) or simply "DDD", from the initials of "direct distance dialing"
    # https://en.wikipedia.org/wiki/Telephone_numbers_in_Brazil
    ddd = phone_number[2, 2]
    # Remove country code and DDD to obtain the number
    number = phone_number[4, phone_number.length - 4]
    normalised_number = "55#{ddd}#{number}"
    # insert 9 to convert the number to the new mobile number format
    normalised_number = "55#{ddd}9#{number}" if normalised_number.length != 13
    normalised_number
  end

  # Inverse of normalised_brazil_mobile_number for the with-9 → without-9 lookup.
  # Only strips when the number matches 55 + DDD + 9 + 8 digits.
  def brazil_mobile_number_without_ninth_digit(phone_number)
    return unless phone_number.to_s.length == 13

    ddd = phone_number[2, 2]
    ninth_digit = phone_number[4]
    subscriber = phone_number[5, 8]
    return unless ninth_digit == '9' && subscriber.to_s.length == 8

    "55#{ddd}#{subscriber}"
  end

  def brazil_mobile_source_id_candidates(waid)
    [
      waid,
      normalised_brazil_mobile_number(waid),
      brazil_mobile_number_without_ninth_digit(waid)
    ].compact.uniq
  end

  def processed_waid(waid)
    # Bidirectional BR mobile matching (production-safe):
    # - incoming without 9 → find existing with 9
    # - incoming with 9 → find existing without 9
    # Prefer the existing contact_inbox.source_id (no rewrite / no auto-merge).
    # https://github.com/chatwoot/chatwoot/issues/5840
    return waid unless brazil_phone_number?(waid)

    brazil_mobile_source_id_candidates(waid).each do |candidate|
      contact_inbox = inbox.contact_inboxes.find_by(source_id: candidate)
      return contact_inbox.source_id if contact_inbox.present?
    end

    waid
  end

  def error_webhook_event?(message)
    message.key?('errors')
  end

  def log_error(message)
    Rails.logger.warn "Whatsapp Error: #{message['errors'][0]['title']} - contact: #{message['from']}"
  end

  def process_in_reply_to(message)
    @in_reply_to_interactive_id = message['interactive']&.[]('list_reply')&.[]('id') || message['interactive']&.[]('button_reply')&.[]('id')
    @in_reply_to_external_id = message['context']&.[]('id')
  end

  def find_message_by_source_id(source_id)
    return unless source_id

    @message = Message.find_by(source_id: source_id)
  end

  def whatsapp_phone_number(identifier)
    identifier = identifier.to_s
    return if identifier.blank?
    return unless identifier.match?(/\A\d{1,15}\z/)

    identifier
  end

  def lock_message_source_id!(source_id = nil)
    source_id ||= @processed_params.try(:[], :messages)&.first&.dig(:id)
    source_id ||= @processed_params.try(:[], :message_echoes)&.first&.dig(:id)
    return false if source_id.blank?

    Whatsapp::MessageDedupLock.new(source_id).acquire!
  end

  def messages_data
    @processed_params&.dig(:messages) || @processed_params&.dig(:message_echoes)
  end
end
