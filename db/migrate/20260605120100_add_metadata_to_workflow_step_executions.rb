# frozen_string_literal: true

class AddMetadataToWorkflowStepExecutions < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_step_executions, :metadata, :jsonb, default: {}, null: false
  end
end
