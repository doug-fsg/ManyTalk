module SortHandler
  extend ActiveSupport::Concern

  class_methods do
    def sort_on_last_activity_at(sort_direction = :desc)
      order(last_activity_at: sort_direction)
    end

    def sort_on_created_at(sort_direction = :asc)
      order(created_at: sort_direction)
    end

    def sort_on_priority(sort_direction = :desc)
      order(generate_sql_query("priority #{sort_direction.to_s.upcase} NULLS LAST, last_activity_at DESC"))
    end

    def sort_on_waiting_since(sort_direction = :asc)
      order(generate_sql_query("waiting_since #{sort_direction.to_s.upcase} NULLS LAST, created_at ASC"))
    end

    def sort_on_sla_urgency(_sort_direction = :asc)
      return sort_on_last_activity_at(:desc) unless ChatwootApp.enterprise?

      current_epoch = Time.zone.now.to_i
      urgency_expression = <<~SQL.squish
        LEAST(
          CASE
            WHEN sla_policies.first_response_time_threshold IS NOT NULL
              AND conversations.first_reply_created_at IS NULL
            THEN ABS(
              EXTRACT(EPOCH FROM applied_slas.created_at)
              + sla_policies.first_response_time_threshold
              - #{current_epoch}
            )
          END,
          CASE
            WHEN sla_policies.next_response_time_threshold IS NOT NULL
              AND conversations.first_reply_created_at IS NOT NULL
              AND conversations.waiting_since IS NOT NULL
            THEN ABS(
              EXTRACT(EPOCH FROM conversations.waiting_since)
              + sla_policies.next_response_time_threshold
              - #{current_epoch}
            )
          END,
          CASE
            WHEN conversations.status = 0
              AND sla_policies.resolution_time_threshold IS NOT NULL
            THEN ABS(
              EXTRACT(EPOCH FROM applied_slas.created_at)
              + sla_policies.resolution_time_threshold
              - #{current_epoch}
            )
          END
        )
      SQL

      joins('LEFT OUTER JOIN applied_slas ON applied_slas.conversation_id = conversations.id')
        .joins('LEFT OUTER JOIN sla_policies ON sla_policies.id = applied_slas.sla_policy_id')
        .order(Arel.sql("#{urgency_expression} ASC NULLS LAST, conversations.last_activity_at DESC"))
    end

    def sort_on_messaging_window_expires(_sort_direction = :asc)
      last_incoming_epoch_sql = <<~SQL.squish
        (
          SELECT EXTRACT(EPOCH FROM m.created_at)
          FROM messages m
          WHERE m.conversation_id = conversations.id
            AND m.message_type = 0
          ORDER BY m.created_at DESC
          LIMIT 1
        )
      SQL

      expires_epoch_sql = "(#{last_incoming_epoch_sql}) + #{24.hours.to_i}"

      order(
        Arel.sql(
          "#{expires_epoch_sql} ASC NULLS LAST, conversations.last_activity_at DESC"
        )
      )
    end

    def last_messaged_conversations
      Message.except(:order).select(
        'DISTINCT ON (conversation_id) conversation_id, id, created_at, message_type'
      ).order('conversation_id, created_at DESC')
    end

    def sort_on_last_user_message_at
      order('grouped_conversations.message_type', 'grouped_conversations.created_at ASC')
    end

    private

    def generate_sql_query(query)
      Arel::Nodes::SqlLiteral.new(sanitize_sql_for_order(query))
    end
  end
end
