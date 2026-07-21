# frozen_string_literal: true

class CreateContactPipelineEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :contact_pipeline_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :contact_pipeline_position, null: false, foreign_key: true
      t.bigint :pipeline_id, null: false
      t.string :event_type, null: false
      t.string :from_stage_id
      t.string :to_stage_id
      t.jsonb :metadata, null: false, default: {}
      t.references :user, foreign_key: true
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :contact_pipeline_events, [:contact_id, :occurred_at],
              name: 'index_contact_pipeline_events_on_contact_and_occurred_at'
    add_index :contact_pipeline_events, [:contact_pipeline_position_id, :occurred_at],
              name: 'index_contact_pipeline_events_on_position_and_occurred_at'
    add_index :contact_pipeline_events, [:account_id, :occurred_at],
              name: 'index_contact_pipeline_events_on_account_and_occurred_at'
    add_index :contact_pipeline_events, :pipeline_id
    add_index :contact_pipeline_events, :event_type
  end
end
