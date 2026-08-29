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

  # ref: https://github.com/chatwoot/chatwoot/issues/5840
  # Prefer existing contact_inbox.source_id across BR mobile with/without 9.
  # Never rewrite Meta's wa_id when creating a new contact_inbox.
  def processed_waid(waid)
    Contacts::BrazilPhoneNormalizer.resolve_inbox_source_id(inbox: inbox, waid: waid)
  end

  def brazil_mobile_source_id_candidates(waid)
    Contacts::BrazilPhoneNormalizer.source_id_candidates(waid)
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
