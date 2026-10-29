# frozen_string_literal: true

class CreateAiAttendantConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_attendant_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :inbox_id, null: false
      t.boolean :active, null: false, default: false
      t.string :pause_reason
      t.string :digital_agent_name
      t.text :agent_role
      t.text :agent_duties
      t.text :agent_objective
      t.jsonb :behavior_steps, null: false, default: []
      t.text :company_context
      t.jsonb :topics_to_avoid, null: false, default: []
      t.text :handoff_conditions
      t.text :handoff_customer_message
      t.string :schedule_mode, null: false, default: 'always'
      t.boolean :detect_language, null: false, default: false
      t.integer :debounce_seconds, null: false, default: 5
      t.string :many_ia_config_id
      t.references :sender_user, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :ai_attendant_configs, [:account_id, :inbox_id], unique: true
  end
end
