# frozen_string_literal: true

class CreateWorkflows < ActiveRecord::Migration[7.0]
  def change
    create_table :workflows do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: false, null: false
      t.jsonb :graph, null: false, default: {}
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :workflows, [:account_id, :active]

    create_table :workflow_enrollments do |t|
      t.references :workflow, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :status, null: false, default: 'active'
      t.string :current_node_id
      t.string :cancel_reason
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :workflow_enrollments, [:workflow_id, :conversation_id],
              unique: true,
              where: "status IN ('active', 'waiting')",
              name: 'index_workflow_enrollments_unique_active'

    add_index :workflow_enrollments, [:account_id, :conversation_id]

    create_table :workflow_step_executions do |t|
      t.references :workflow_enrollment, null: false, foreign_key: true, index: { name: 'index_wse_on_enrollment_id' }
      t.string :node_id, null: false
      t.string :status, null: false, default: 'scheduled'
      t.datetime :scheduled_at
      t.datetime :executed_at
      t.string :job_id
      t.text :error_message

      t.timestamps
    end

    add_index :workflow_step_executions, [:workflow_enrollment_id, :node_id],
              unique: true,
              name: 'index_wse_unique_enrollment_node'
  end
end
