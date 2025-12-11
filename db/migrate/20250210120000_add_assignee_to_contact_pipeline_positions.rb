class AddAssigneeToContactPipelinePositions < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_pipeline_positions, :assignee_id, :bigint
    add_index :contact_pipeline_positions, :assignee_id
    add_foreign_key :contact_pipeline_positions, :users, column: :assignee_id
  end
end

