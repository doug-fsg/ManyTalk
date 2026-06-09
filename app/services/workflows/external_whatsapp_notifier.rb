# frozen_string_literal: true

module Workflows
  class ExternalWhatsappNotifier
    pattr_initialize [:account!, :inbox_id!, :phone_number!, :message!]

    def send!
      inbox = account.inboxes.find_by(id: inbox_id)
      return failure('inbox_not_found') if inbox.blank?
      return failure('not_whatsapp') unless inbox.channel_type == 'Channel::Whatsapp'

      normalized = normalize_phone(phone_number)
      return failure('invalid_phone') if normalized.blank?
      return failure('empty_message') if message.to_s.strip.blank?

      channel = inbox.channel
      stub = OpenStruct.new(
        content: message.to_s,
        attachments: [],
        content_type: 'text',
        content_attributes: {},
        sender_name: nil
      )

      message_id = channel.send_message(normalized, stub)
      return failure('send_failed') if message_id.blank?

      { success: true, message_id: message_id }
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
      failure('send_failed', e.message)
    end

    private

    def normalize_phone(phone)
      digits = phone.to_s.gsub(/\D/, '')
      digits.presence
    end

    def failure(code, detail = nil)
      { success: false, error: code, detail: detail }.compact
    end
  end
end
