# frozen_string_literal: true

module Workflows
  class ExternalWhatsappNotifier
    pattr_initialize [:account!, :inbox_id!, :phone_number!, :message!]

    def send!
      inbox = account.inboxes.find_by(id: inbox_id.to_i)
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
      stub = ExternalWhatsappMessage.new(message)

      message_id = channel.send_message(
        Workflows::PhoneNormalizer.new(phone_number).whatsapp_digits,
        stub
      )
      return failure('send_failed') if message_id.blank?

      { success: true, message_id: message_id }
    end

    def send_via_whatsapp_web(inbox, normalized)
      webhook_url = resolve_whatsapp_web_url(inbox)
      return failure('webhook_url_missing') if webhook_url.blank?

      normalizer = Workflows::PhoneNormalizer.new(phone_number)
      payload = {
        event: 'workflow.external_whatsapp',
        content: message.to_s,
        phone_number: normalized,
        phone_jid: normalizer.jid,
        notification_only: true,
        account: account.webhook_data,
        inbox: inbox.webhook_data.merge(
          channel_id: inbox.channel_id,
          webhook_url: webhook_url
        )
      }

      response = RestClient::Request.execute(
        method: :post,
        url: webhook_url,
        payload: payload.to_json,
        headers: { content_type: :json, accept: :json },
        timeout: ENV.fetch('WEBHOOKS_TRIGGER_TIMEOUT', '15').to_i
      )

      return { success: true, delivery: 'webhook' } if response.code.to_i.between?(200, 299)

      failure('webhook_failed', response.body)
    rescue RestClient::ExceptionWithResponse => e
      failure('webhook_failed', e.response&.body || e.message)
    end

    def resolve_whatsapp_web_url(inbox)
      env_url = ENV.fetch('WEBHOOK_URL', nil).presence
      channel_url = inbox.channel&.webhook_url.presence

      # WhatsApp Web (Quepasa) uses WEBHOOK_URL globally — same as WhatsappWebConnectionsController.
      return env_url if inbox.whatsapp_web? && env_url.present?

      channel_url || env_url
    end

    def failure(code, detail = nil)
      { success: false, error: code, detail: detail }.compact
    end
  end
end
