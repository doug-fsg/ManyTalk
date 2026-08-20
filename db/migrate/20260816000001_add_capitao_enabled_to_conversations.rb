class AddCapitaoEnabledToConversations < ActiveRecord::Migration[7.0]
  def up
    add_column :conversations, :capitao_enabled, :boolean, default: true, null: false
    add_index :conversations, [:account_id, :capitao_enabled], name: 'index_conversations_on_account_id_and_capitao_enabled'
    execute <<-SQL.squish
      UPDATE conversations SET capitao_enabled = FALSE WHERE assignee_id IS NOT NULL
    SQL
  end

  def down
    remove_index :conversations, name: 'index_conversations_on_account_id_and_capitao_enabled'
    remove_column :conversations, :capitao_enabled
  end
end
