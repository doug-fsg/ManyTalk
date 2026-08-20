class AddCapitaoToAgentBots < ActiveRecord::Migration[7.0]
  def change
    add_column :agent_bots, :capitao, :boolean, default: false, null: false
    add_index :agent_bots, :capitao, unique: true, where: 'capitao IS TRUE',
              name: 'index_agent_bots_unique_capitao'
  end
end
