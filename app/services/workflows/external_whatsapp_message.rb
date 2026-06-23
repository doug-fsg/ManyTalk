# frozen_string_literal: true

module Workflows
  # Minimal message stand-in for WhatsApp provider APIs (avoids OpenStruct#update! on failure).
  class ExternalWhatsappMessage
    attr_accessor :content, :attachments, :content_type, :content_attributes, :sender_name

    def initialize(content)
      @content = content.to_s
      @attachments = []
      @content_type = 'text'
      @content_attributes = {}
      @sender_name = nil
    end

    def update!(_attrs)
      # no-op — providers call this when API returns an error
    end
  end
end
