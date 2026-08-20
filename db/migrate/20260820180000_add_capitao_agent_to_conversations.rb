class AddCapitaoAgentToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :capitao_agent, :jsonb
  end
end
