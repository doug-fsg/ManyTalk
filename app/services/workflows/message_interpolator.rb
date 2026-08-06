# frozen_string_literal: true

module Workflows
  class MessageInterpolator
    VARIABLE_PATTERN = /\{\{([a-z_][a-z0-9_.]*)\}\}/i.freeze

    def initialize(conversation)
      @conversation = conversation
      @contact = conversation.contact
      @account = conversation.account
    end

    def interpolate(template)
      return template if template.blank?

      template.gsub(VARIABLE_PATTERN) do
        key = Regexp.last_match(1)
        value = resolve(key)
        ERB::Util.html_escape(value.to_s)
      end
    end

    def self.available_variables
      %w[
        contact.name
        contact.first_name
        contact.last_name
        contact.email
        contact.phone
        contact.phone_number
        agent.name
        agent.first_name
        agent.last_name
        agent.email
        conversation.id
      ]
    end

    private

    def resolve(key)
      case key
      when 'contact.name' then @contact&.name
      when 'contact.first_name' then first_name(@contact&.name)
      when 'contact.last_name' then last_name(@contact&.name)
      when 'contact.email' then @contact&.email
      when 'contact.phone', 'contact.phone_number' then @contact&.phone_number
      when 'agent.name' then @conversation.assignee&.name
      when 'agent.first_name' then first_name(@conversation.assignee&.name)
      when 'agent.last_name' then last_name(@conversation.assignee&.name)
      when 'agent.email' then @conversation.assignee&.email
      when 'conversation.id' then @conversation.display_id
      else
        resolve_custom(key)
      end
    end

    def first_name(name)
      name.to_s.split.first
    end

    def last_name(name)
      parts = name.to_s.split
      parts.length > 1 ? parts[1..].join(' ') : ''
    end

    def resolve_custom(key)
      return nil unless key.start_with?('custom.')

      attr_key = key.delete_prefix('custom.')
      (@contact&.custom_attributes || {})[attr_key]
    end
  end
end
