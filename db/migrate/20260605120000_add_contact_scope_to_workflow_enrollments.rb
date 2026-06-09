# frozen_string_literal: true

class AddContactScopeToWorkflowEnrollments < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    add_column :workflow_enrollments, :contact_id, :bigint
    add_column :workflow_enrollments, :enrollment_scope, :string, default: 'contact', null: false

    backfill_contact_ids

    change_column_null :workflow_enrollments, :contact_id, false
    add_index :workflow_enrollments, :contact_id
    add_index :workflow_enrollments, [:account_id, :contact_id],
              name: 'index_we_on_account_id_and_contact_id'

    add_index :workflow_enrollments, [:workflow_id, :contact_id],
              unique: true,
              where: "status IN ('active', 'waiting', 'paused') AND enrollment_scope = 'contact'",
              name: 'index_we_unique_active_contact_scope',
              algorithm: :concurrently

    add_index :workflow_enrollments, [:account_id, :status],
              where: "status IN ('active', 'waiting', 'paused')",
              name: 'idx_we_in_progress_by_account',
              algorithm: :concurrently
  end

  def down
    remove_index :workflow_enrollments, name: 'idx_we_in_progress_by_account'
    remove_index :workflow_enrollments, name: 'index_we_unique_active_contact_scope'
    remove_index :workflow_enrollments, name: 'index_we_on_account_id_and_contact_id'
    remove_index :workflow_enrollments, :contact_id
    remove_column :workflow_enrollments, :enrollment_scope
    remove_column :workflow_enrollments, :contact_id
  end

  private

  def backfill_contact_ids
    WorkflowEnrollment.reset_column_information
    WorkflowEnrollment.find_in_batches(batch_size: 500) do |batch|
      batch.each do |enrollment|
        contact_id = Conversation.where(id: enrollment.conversation_id).pick(:contact_id)
        enrollment.update_column(:contact_id, contact_id) if contact_id.present?
      end
    end
  end
end
