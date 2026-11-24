# frozen_string_literal: true

module AiAttendant
  class HistoryMapper
    HUMAN_PREFIX = '[Mensagem de atendente humano]'

    class << self
      def call(conversation:, exclude_ids: [], limit: 10)
        conversation.messages
                    .includes(:sender)
                    .where(private: false, message_type: %i[incoming outgoing])
                    .where.not(id: Array(exclude_ids))
                    .reorder(created_at: :desc, id: :desc)
                    .limit(limit)
                    .to_a
                    .reverse
                    .filter_map { |message| map_message(message) }
      end

      def map_message(message)
        content = message.content.to_s
        return if content.blank?

        if message.incoming?
          { role: 'user', content: content }
        elsif ai_sender?(message)
          { role: 'assistant', content: content }
        else
          { role: 'user', content: "#{HUMAN_PREFIX}\n#{content}" }
        end
      end

      private

      def ai_sender?(message)
        message.sender_type == 'AgentBot' || message.sender.is_a?(AgentBot)
      end
    end
  end
end
