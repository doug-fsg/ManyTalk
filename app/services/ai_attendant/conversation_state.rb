# frozen_string_literal: true

module AiAttendant
  class ConversationState
    HANDOFF_KEY = 'ai_handoff_at'
    PROGRESS_KEY = 'ai_behavior_progress'

    class << self
      def handed_off?(conversation)
        return false if conversation.blank?

        attributes_for(conversation)[HANDOFF_KEY].present?
      end

      def mark_handoff!(conversation)
        merge!(conversation, HANDOFF_KEY => Time.current.iso8601)
      end

      def clear_handoff!(conversation)
        return if conversation.blank? || !conversation.persisted?

        reload_if_dirty!(conversation)
        conversation.with_lock do
          current = attributes_for(conversation)
          next if current[HANDOFF_KEY].blank?

          conversation.update!(additional_attributes: current.except(HANDOFF_KEY))
        end
      end

      def step_index(conversation)
        raw = attributes_for(conversation)[PROGRESS_KEY]
        return 0 unless raw.is_a?(Hash)

        raw['step_index'].to_i
      end

      def write_progress!(conversation, step_index)
        merge!(conversation, PROGRESS_KEY => { 'step_index' => step_index.to_i })
      end

      private

      def attributes_for(conversation)
        raw = conversation.additional_attributes
        raw.is_a?(Hash) ? raw.stringify_keys : {}
      end

      def merge!(conversation, patch)
        reload_if_dirty!(conversation)
        conversation.with_lock do
          current = attributes_for(conversation)
          conversation.update!(additional_attributes: current.merge(patch.stringify_keys))
        end
      end

      def reload_if_dirty!(conversation)
        conversation.reload if conversation.persisted? && conversation.changed?
      end
    end
  end
end
