# frozen_string_literal: true

module Workflows
  class ExternalWhatsappNotifier
    pattr_initialize [:account!, :inbox_id!, :phone_number!, :message!]

    def send!
      inbox = account.inboxes.find_by(id: inbox_id)
      return failure('inbox_not_found') if inbox.blank?
      return failure('empty_message') if message.to_s.strip.blank?

      normalized = Workflows::PhoneNormalizer.normalize(phone_number)
      return failure('invalid_phone') if normalized.blank?

      case inbox.channel_type
      when 'Channel::Whatsapp'
        send_via_whatsapp_channel(inbox, normalized)
      when 'Channel::Api'
        return failure('not_whatsapp_web') unless inbox.whatsapp_web?

        send_via_whatsapp_web(inbox, normalized)
      else
        failure('unsupported_inbox')
      end
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
      failure('send_failed', e.message)
    end

    private

    def send_via_whatsapp_channel(inbox, normalized)
      channel = inbox.channel
      stub = OpenStruct.new(
        content: message.to_s,
        attachments: [],
        content_type: 'text',
        content_attributes: {},
        sender_name: nil
      )

      message_id = channel.send_message(Workflows::PhoneNormalizer.new(phone_number).whatsapp_digits, stub)
      return failure('send_failed') if message_id.blank?

      { success: true, message_id: message_id }
    end

    def send_via_whatsapp_web(inbox, normalized)
      webhook_url = inbox.channel.webhook_url.presence || ENV.fetch('WEBHOOK_URL', nil)
      return failure('webhook_url_missing') if webhook_url.blank?

      normalizer = Workflows::PhoneNormalizer.new(phone_number)
      payload = {
        event: 'workflow.external_whatsapp',
        content: message.to_s,
        phone_number: normalized,
        phone_jid: normalizer.jid,
        notification_only: true,
        account: account.webhook_data,
        inbox: inbox.webhook_data
      }

      WebhookJob.perform_later(webhook_url, payload, :api_inbox_webhook)
      { success: true, delivery: 'webhook' }
    end

    def failure(code, detail = nil)
      { success: false, error: code, detail: detail }.compact
    end
  end
end
