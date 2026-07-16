# frozen_string_literal: true

module Messages
  class LiquidInterpolatorService
    pattr_initialize [:conversation!, :sender]

    def interpolate(text)
      return text if text.blank?

      Liquid::Template.parse(text.to_s).render(drops)
    rescue Liquid::Error
      text.to_s
    end

    def interpolate_value(value)
      case value
      when Hash
        value.transform_values { |entry| interpolate_value(entry) }
      when Array
        value.map { |entry| interpolate_value(entry) }
      when String
        interpolate(value)
      else
        value
      end
    end

    private

    def drops
      @drops ||= {
        'contact' => ContactDrop.new(conversation.contact),
        'agent' => UserDrop.new(sender),
        'conversation' => ConversationDrop.new(conversation),
        'inbox' => InboxDrop.new(conversation.inbox),
        'account' => AccountDrop.new(conversation.account)
      }
    end
  end
end
