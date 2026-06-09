# frozen_string_literal: true

class AddContextToWorkflowEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_enrollments, :context, :jsonb, default: {}, null: false
  end
end
