# frozen_string_literal: true

module Workflows
  # Sends a WhatsApp message to an external number using the same delivery path as a
  # normal outgoing message (conversation + MessageBuilder), while keeping the
  # conversation snoozed so it does not appear in the open chat queue.
  class ExternalWhatsappNotifier
    EXTERNAL_ATTR = 'workflow_external_whatsapp'

    pattr_initialize [:account!, :inbox_id!, :phone_number!, :message!]

    def send!
      inbox = account.inboxes.find_by(id: inbox_id.to_i)
      return failure('inbox_not_found') if inbox.blank?
      return failure('empty_message') if message.to_s.strip.blank?
      return failure('unsupported_inbox') unless inbox.external_whatsapp_capable?
      return failure('webhook_url_missing') unless ensure_delivery_ready?(inbox)

      normalized = Workflows::PhoneNormalizer.normalize(phone_number)
      return failure('invalid_phone') if normalized.blank?

      digits = Workflows::PhoneNormalizer.new(phone_number).whatsapp_digits
      return failure('invalid_phone') if digits.blank?

      contact = find_or_create_contact(normalized)
      contact_inbox = find_or_create_contact_inbox(inbox, contact, digits)
      conversation = find_or_create_snoozed_conversation(inbox, contact, contact_inbox)
      ensure_snoozed!(conversation)

      built = Messages::MessageBuilder.new(
        nil,
        conversation,
        content: message.to_s,
        private: false,
        message_type: 'outgoing'
      ).perform

      ensure_snoozed!(conversation.reload)

      { success: true, message_id: built.id, conversation_id: conversation.display_id }
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
      failure('send_failed', e.message)
    end

    private

    def ensure_delivery_ready?(inbox)
      return true if inbox.whatsapp?
      return false unless inbox.whatsapp_web?

      channel = inbox.channel
      return true if channel.webhook_url.present?

      env_url = ENV.fetch('WEBHOOK_URL', nil).presence
      return false if env_url.blank?

      channel.update!(webhook_url: env_url)
      true
    end

    def find_or_create_contact(normalized)
      account.contacts.find_or_create_by!(phone_number: normalized) do |contact|
        contact.name = normalized
      end
    end

    def find_or_create_contact_inbox(inbox, contact, digits)
      ContactInboxBuilder.new(
        contact: contact,
        inbox: inbox,
        source_id: digits
      ).perform
    end

    def find_or_create_snoozed_conversation(inbox, contact, contact_inbox)
      conversation = Conversation.where(
        account_id: account.id,
        inbox_id: inbox.id,
        contact_id: contact.id,
        status: :snoozed
      ).where('additional_attributes @> ?', { EXTERNAL_ATTR => true }.to_json)
       .order(updated_at: :desc)
       .first

      return conversation if conversation.present?

      Conversation.create!(
        account_id: account.id,
        inbox_id: inbox.id,
        contact_id: contact.id,
        contact_inbox_id: contact_inbox.id,
        status: :snoozed,
        snoozed_until: nil,
        additional_attributes: { EXTERNAL_ATTR => true }
      )
    end

    def ensure_snoozed!(conversation)
      return if conversation.snoozed? && conversation.snoozed_until.nil?

      conversation.update!(status: :snoozed, snoozed_until: nil)
    end

    def failure(code, detail = nil)
      { success: false, error: code, detail: detail }.compact
    end
  end
end
