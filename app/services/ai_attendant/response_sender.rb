# frozen_string_literal: true

module AiAttendant
  class ResponseSender
    def initialize(conversation:, sender:, text:, config: nil)
      @conversation = conversation
      @sender = sender
      @text = text
      @config = config
    end

    def perform
      blocks = AiAttendant::ReplyBlocks.parse(@text, @config)

      blocks.each do |block|
        if block[:type] == :attachment
          send_attachment(block[:file].blob)
        else
          send_text(block[:content])
        end
      end

      blocks.size
    end

    private

    def send_text(content)
      Messages::MessageBuilder.new(@sender, @conversation, { content: content, private: false }).perform
    end

    def send_attachment(blob)
      Messages::MessageBuilder.new(
        @sender,
        @conversation,
        { content: '', private: false, attachments: [blob.signed_id] }
      ).perform
    end
  end
end
