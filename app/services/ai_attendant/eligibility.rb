# frozen_string_literal: true

module AiAttendant
  class Eligibility
    FEATURE_NAME = 'atendimento_ia_nativo'
    UNSUPPORTED_CONTENT_TYPES = %w[sticker].freeze
    # WhatsApp Cloud stickers are stored as Attachment#file_type :image; Graph media
    # Content-Type is image/webp (Whatsapp::IncomingMessageServiceHelpers#file_content_type).
    STICKER_MIME_TYPES = %w[image/webp].freeze
    GIF_MIME_TYPES = %w[image/gif].freeze

    def self.call(message:)
      new(message).call
    end

    def initialize(message)
      @message = message
    end

    def call
      return reject('feature_disabled') unless feature_enabled?
      return reject('config_missing') if config.blank?
      return reject('config_inactive') unless config.active?
      return reject('not_incoming') unless message.incoming?
      return reject('private') if message.private?
      return reject('not_webhook_sendable') unless message.webhook_sendable?
      return reject('unsupported_type') if unsupported_type?
      return reject('audio_unsupported') if audio?
      return reject('assigned') if assigned?
      return reject('handoff') if handoff?

      { eligible: true, reason: nil }
    end

    private

    attr_reader :message

    def reject(reason)
      { eligible: false, reason: reason }
    end

    def feature_enabled?
      message.account.feature_enabled?(FEATURE_NAME)
    end

    def config
      @config ||= AiAttendantConfig.for_inbox(message.inbox_id).find_by(account_id: message.account_id)
    end

    def unsupported_type?
      message.activity? || sticker? || reaction? || gif?
    end

    def sticker?
      UNSUPPORTED_CONTENT_TYPES.include?(message.content_type.to_s) ||
        typed_as?('sticker') ||
        attachment_matches?(mime_types: STICKER_MIME_TYPES, extensions: %w[.webp])
    end

    def reaction?
      typed_as?('reaction') || message.message_type.to_s == 'reaction'
    end

    def gif?
      typed_as?('gif') || attachment_matches?(mime_types: GIF_MIME_TYPES, extensions: %w[.gif])
    end

    def typed_as?(value)
      [content_attr('type'), additional_attr('type')].compact.any? { |type| type.to_s == value }
    end

    def content_attr(key)
      (message.content_attributes || {}).with_indifferent_access[key]
    end

    def additional_attr(key)
      (message.additional_attributes || {}).with_indifferent_access[key]
    end

    def attachment_matches?(mime_types:, extensions:)
      message.attachments.any? do |attachment|
        next false unless attachment.file.attached?

        blob = attachment.file
        content_type = blob.content_type.to_s.downcase
        filename = blob.filename.to_s.downcase
        mime_types.include?(content_type) || extensions.any? { |ext| filename.end_with?(ext) }
      end
    end

    def audio?
      message.attachments.any?(&:audio?)
    end

    def assigned?
      message.conversation.assignee_id.present?
    end

    def handoff?
      message.conversation.contact&.custom_attributes&.[]('ai_handoff_at').present?
    end
  end
end
