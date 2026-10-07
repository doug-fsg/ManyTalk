# frozen_string_literal: true

class AddRecurringToWorkflowSchedules < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_schedules, :recurring, :boolean, default: true, null: false
    change_column_null :workflow_schedules, :weekday, true
  end
end
