class AddCapitaoEnabledToConversations < ActiveRecord::Migration[7.0]
  # Must be outside a single transaction so that:
  # 1) CREATE INDEX CONCURRENTLY is allowed
  # 2) each backfill batch commits independently (no giant rollback)
  disable_ddl_transaction!

  BATCH_SIZE = 5_000

  def up
    unless column_exists?(:conversations, :capitao_enabled)
      # PG 11+: adding boolean with constant default is metadata-only (fast, no rewrite)
      add_column :conversations, :capitao_enabled, :boolean, default: true, null: false
    end

    # Backfill BEFORE the index so UPDATEs do not also maintain the new index.
    backfill_assigned_conversations

    unless index_exists?(:conversations, [:account_id, :capitao_enabled],
                         name: 'index_conversations_on_account_id_and_capitao_enabled')
      # Concurrently avoids long write locks on conversations in production.
      add_index :conversations, [:account_id, :capitao_enabled],
                name: 'index_conversations_on_account_id_and_capitao_enabled',
                algorithm: :concurrently
    end
  end

  def down
    if index_exists?(:conversations, [:account_id, :capitao_enabled],
                     name: 'index_conversations_on_account_id_and_capitao_enabled')
      remove_index :conversations,
                   name: 'index_conversations_on_account_id_and_capitao_enabled',
                   algorithm: :concurrently
    end

    remove_column :conversations, :capitao_enabled if column_exists?(:conversations, :capitao_enabled)
  end

  private

  def backfill_assigned_conversations
    say_with_time 'backfilling capitao_enabled=false for assigned conversations' do
      # Session-level: SET LOCAL only works inside a transaction; we disabled DDL txn.
      previous_timeout = select_value('SHOW statement_timeout')
      execute('SET statement_timeout = 0')

      begin
        loop do
          updated = execute(<<~SQL.squish).cmd_tuples
            WITH batch AS (
              SELECT id
              FROM conversations
              WHERE assignee_id IS NOT NULL
                AND capitao_enabled = TRUE
              ORDER BY id
              LIMIT #{BATCH_SIZE}
            )
            UPDATE conversations
            SET capitao_enabled = FALSE
            FROM batch
            WHERE conversations.id = batch.id
          SQL

          break if updated.zero?
        end
      ensure
        execute("SET statement_timeout = '#{previous_timeout}'")
      end
    end
  end
end
