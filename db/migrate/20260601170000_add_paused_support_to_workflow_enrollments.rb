# frozen_string_literal: true

class AddPausedSupportToWorkflowEnrollments < ActiveRecord::Migration[7.0]
  def up
    change_table :workflow_enrollments, bulk: true do |t|
      t.datetime :paused_at
      t.bigint :paused_by_id
      t.bigint :started_by_id
      t.string :pause_reason
      t.datetime :resume_at
    end

    add_foreign_key :workflow_enrollments, :users, column: :paused_by_id
    add_foreign_key :workflow_enrollments, :users, column: :started_by_id

    remove_index :workflow_enrollments, name: 'index_workflow_enrollments_unique_active'

    add_index :workflow_enrollments, %i[workflow_id conversation_id],
              unique: true,
              where: "status IN ('active', 'waiting', 'paused')",
              name: 'index_workflow_enrollments_unique_active'
  end

  def down
    remove_index :workflow_enrollments, name: 'index_workflow_enrollments_unique_active'

    add_index :workflow_enrollments, %i[workflow_id conversation_id],
              unique: true,
              where: "status IN ('active', 'waiting')",
              name: 'index_workflow_enrollments_unique_active'

    remove_foreign_key :workflow_enrollments, column: :started_by_id
    remove_foreign_key :workflow_enrollments, column: :paused_by_id

    change_table :workflow_enrollments, bulk: true do |t|
      t.remove :paused_at, :paused_by_id, :started_by_id, :pause_reason, :resume_at
    end
  end
end
