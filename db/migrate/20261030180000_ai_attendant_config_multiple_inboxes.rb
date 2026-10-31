# frozen_string_literal: true

class AiAttendantConfigMultipleInboxes < ActiveRecord::Migration[7.0]
  def up
    create_table :ai_attendant_config_inboxes do |t|
      t.references :ai_attendant_config, null: false, foreign_key: true, index: true
      t.integer :inbox_id, null: false
      t.timestamps
    end

    add_index :ai_attendant_config_inboxes, :inbox_id, unique: true

    execute <<~SQL.squish
      INSERT INTO ai_attendant_config_inboxes (ai_attendant_config_id, inbox_id, created_at, updated_at)
      SELECT id, inbox_id, NOW(), NOW()
      FROM ai_attendant_configs
    SQL

    remove_index :ai_attendant_configs, column: %i[account_id inbox_id], if_exists: true
    remove_column :ai_attendant_configs, :inbox_id, :integer
  end

  def down
    add_column :ai_attendant_configs, :inbox_id, :integer
    execute <<~SQL.squish
      UPDATE ai_attendant_configs AS configs
      SET inbox_id = links.inbox_id
      FROM (
        SELECT DISTINCT ON (ai_attendant_config_id) ai_attendant_config_id, inbox_id
        FROM ai_attendant_config_inboxes
        ORDER BY ai_attendant_config_id, id
      ) AS links
      WHERE configs.id = links.ai_attendant_config_id
    SQL
    change_column_null :ai_attendant_configs, :inbox_id, false
    add_index :ai_attendant_configs, %i[account_id inbox_id], unique: true

    drop_table :ai_attendant_config_inboxes
  end
end
