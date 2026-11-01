# frozen_string_literal: true

module AiAttendant
  class BehaviorProgress
    Progress = Struct.new(:conversation_id, :step_index, keyword_init: true)

    class << self
      def load(conversation:)
        Progress.new(
          conversation_id: conversation&.id,
          step_index: AiAttendant::ConversationState.step_index(conversation)
        )
      end

      def advance!(conversation:, script:, evidence:)
        raise ArgumentError, 'conversation required' if conversation.blank?

        progress = load(conversation: conversation)
        return failure('already_complete') if script.step_count.zero?
        return failure('already_complete') if progress.step_index >= script.step_count

        previous_index = progress.step_index
        new_index = previous_index + 1
        AiAttendant::ConversationState.write_progress!(conversation, new_index)

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

      def failure(error)
        { ok: false, error: error }
      end
    end
  end
end
