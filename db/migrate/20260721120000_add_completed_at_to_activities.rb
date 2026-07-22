# frozen_string_literal: true

class AddCompletedAtToActivities < ActiveRecord::Migration[7.0]
  def up
    add_column :activities, :completed_at, :datetime
    add_index :activities, [:account_id, :completed_at]

    execute <<-SQL.squish
      UPDATE activities
      SET completed_at = updated_at
      WHERE status = 'completed' AND completed_at IS NULL
    SQL
  end

  def down
    remove_index :activities, column: [:account_id, :completed_at]
    remove_column :activities, :completed_at
  end
end
