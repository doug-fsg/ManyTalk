# frozen_string_literal: true

module AiAttendant
  class BehaviorProgress
    ATTRIBUTE_KEY = 'ai_behavior_progress'

    Progress = Struct.new(:conversation_id, :step_index, keyword_init: true)

    class << self
      def load(contact:, conversation:)
        raw = (contact&.custom_attributes || {})[ATTRIBUTE_KEY]
        return fresh(conversation) unless raw.is_a?(Hash)

        stored_conversation_id = raw['conversation_id'].to_i
        return fresh(conversation) if stored_conversation_id != conversation.id

        Progress.new(
          conversation_id: conversation.id,
          step_index: raw['step_index'].to_i
        )
      end

      def fresh(conversation)
        Progress.new(conversation_id: conversation.id, step_index: 0)
      end

      def advance!(contact:, conversation:, script:, evidence:)
        raise ArgumentError, 'contact required' if contact.blank?

        progress = load(contact: contact, conversation: conversation)
        return failure('already_complete') if script.step_count.zero?
        return failure('already_complete') if progress.step_index >= script.step_count

        previous_index = progress.step_index
        new_index = previous_index + 1
        persist!(contact, conversation, new_index)

        {
          ok: true,
          previous_index: previous_index,
          current_index: new_index,
          completed_all: new_index >= script.step_count,
          evidence: evidence.to_s
        }
      end

      def sandbox_advance(script:, step_index:, evidence:)
        return failure('already_complete') if script.step_count.zero?
        return failure('already_complete') if step_index >= script.step_count

        new_index = step_index + 1
        {
          ok: true,
          previous_index: step_index,
          current_index: new_index,
          completed_all: new_index >= script.step_count,
          evidence: evidence.to_s,
          sandbox: true
        }
      end

      private

      def persist!(contact, conversation, step_index)
        merged = (contact.custom_attributes || {}).merge(
          ATTRIBUTE_KEY => {
            'conversation_id' => conversation.id,
            'step_index' => step_index
          }
        )
        contact.update!(custom_attributes: merged)
      end

      def failure(error)
        { ok: false, error: error }
      end
    end
  end
end
