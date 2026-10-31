# frozen_string_literal: true

class CreateAiAttendantRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_attendant_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :conversation_id, null: false
      t.integer :inbox_id, null: false
      t.string :status, null: false
      t.string :skip_reason
      t.integer :tokens, default: 0, null: false
      t.text :error_message
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :ai_attendant_runs, :conversation_id
    add_index :ai_attendant_runs, :inbox_id
    add_index :ai_attendant_runs, [:account_id, :created_at]
  end
end
