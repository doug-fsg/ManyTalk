# frozen_string_literal: true

module Events
  # Serializes event payloads for async dispatch so Sidekiq jobs do not fail with
  # ActiveJob::DeserializationError when referenced records were deleted before the job runs.
  module PayloadSerializer
    AR_MARKER = '__ar__'

    module_function

    def dump(value)
      case value
      when Hash
        value.transform_keys(&:to_s).transform_values { |entry| dump(entry) }
      when Array
        value.map { |entry| dump(entry) }
      when ActiveRecord::Base
        { AR_MARKER => value.class.name, 'id' => value.id }
      else
        value
      end
    end

    def load(value)
      case value
      when Hash
        if value.key?(AR_MARKER)
          klass = value[AR_MARKER].safe_constantize
          return nil if klass.blank?

          klass.find_by(id: value['id'])
        else
          value.transform_keys(&:to_sym).transform_values { |entry| load(entry) }
        end
      when Array
        value.map { |entry| load(entry) }
      else
        value
      end
    end

    def primary_key_for(event_name)
      PRIMARY_KEYS[event_name]
    end

    def missing_primary_record?(event_name, data)
      key = primary_key_for(event_name)
      return false if key.blank?

      data[key].blank?
    end

    PRIMARY_KEYS = {
      Events::Types::MESSAGE_CREATED => :message,
      Events::Types::MESSAGE_UPDATED => :message,
      Events::Types::FIRST_REPLY_CREATED => :message,
      Events::Types::REPLY_CREATED => :message,
      Events::Types::CONVERSATION_CREATED => :conversation,
      Events::Types::CONVERSATION_UPDATED => :conversation,
      Events::Types::CONVERSATION_READ => :conversation,
      Events::Types::CONVERSATION_BOT_HANDOFF => :conversation,
      Events::Types::CONVERSATION_OPENED => :conversation,
      Events::Types::CONVERSATION_RESOLVED => :conversation,
      Events::Types::CONVERSATION_STATUS_CHANGED => :conversation,
      Events::Types::CONVERSATION_CONTACT_CHANGED => :conversation,
      Events::Types::ASSIGNEE_CHANGED => :conversation,
      Events::Types::TEAM_CHANGED => :conversation,
      Events::Types::CONVERSATION_TYPING_ON => :conversation,
      Events::Types::CONVERSATION_TYPING_OFF => :conversation,
      Events::Types::CONVERSATION_MENTIONED => :conversation,
      Events::Types::CONTACT_CREATED => :contact,
      Events::Types::CONTACT_UPDATED => :contact,
      Events::Types::CONTACT_KANBAN_STAGE_CHANGED => :contact,
      Events::Types::CONTACT_MERGED => :contact,
      Events::Types::CONTACT_DELETED => :contact,
      Events::Types::INBOX_CREATED => :inbox,
      Events::Types::INBOX_UPDATED => :inbox,
      Events::Types::NOTIFICATION_CREATED => :notification,
      Events::Types::NOTIFICATION_UPDATED => :notification,
      Events::Types::NOTIFICATION_DELETED => :notification,
      Events::Types::WEBWIDGET_TRIGGERED => :contact_inbox,
      Events::Types::WORKFLOW_ENROLLMENT_UPDATED => :enrollment
    }.freeze
  end
end
