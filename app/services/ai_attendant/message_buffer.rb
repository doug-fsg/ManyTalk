# frozen_string_literal: true

module AiAttendant
  class MessageBuffer
    pattr_initialize [:account_id!, :inbox_id!, :conversation_id!]

    def push(message_id:, content:, debounce_seconds:)
      payload = { 'message_id' => message_id, 'content' => content }.to_json
      length = Redis::Alfred.lpush(buffer_key, payload)
      refresh_ttl(debounce_seconds)

      length == 1 ? :leader : :follower
    end

    def combined_content
      entries.reverse.filter_map { |entry| entry['content'].presence }.join("\n")
    end

    def clear!
      Redis::Alfred.delete(buffer_key)
    end

    private

    def buffer_key
      format(
        Redis::Alfred::AI_ATTENDANT_BUFFER,
        account_id: account_id,
        inbox_id: inbox_id,
        conversation_id: conversation_id
      )
    end

    def entries
      Redis::Alfred.lrange(buffer_key).map { |raw| JSON.parse(raw) }
    end

    def refresh_ttl(debounce_seconds)
      ttl = debounce_seconds.to_i
      return if ttl <= 0

      # Slack so the leader job can still read after waiting debounce_seconds.
      $alfred.with { |conn| conn.expire(buffer_key, ttl + 60) }
    end
  end
end
