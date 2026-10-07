# frozen_string_literal: true

class CreateWorkflowSchedules < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_schedules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :workflow, null: false, foreign_key: true
      t.bigint :pipeline_id, null: false
      t.string :stage_id, null: false
      t.string :name, null: false
      t.integer :weekday, null: false
      t.integer :hour, null: false
      t.integer :minute, null: false, default: 0
      t.string :time_zone, null: false, default: 'America/Sao_Paulo'
      t.boolean :active, null: false, default: false
      t.datetime :next_run_at
      t.datetime :last_enqueued_at
      t.datetime :last_finished_at
      t.string :last_run_status
      t.jsonb :last_run_stats, null: false, default: {}
      t.integer :run_token, null: false, default: 0
      t.bigint :created_by_id
      t.timestamps
    end

    add_index :workflow_schedules, [:active, :next_run_at],
              name: 'idx_workflow_schedules_due',
              where: 'active = true'
    add_index :workflow_schedules, [:account_id, :active],
              name: 'idx_workflow_schedules_account_active'
    add_index :workflow_schedules, :pipeline_id
    add_foreign_key :workflow_schedules, :custom_attribute_definitions, column: :pipeline_id
    add_foreign_key :workflow_schedules, :users, column: :created_by_id
  end
end
