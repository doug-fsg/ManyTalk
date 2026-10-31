# frozen_string_literal: true

class AddBehaviorStepModeToAiAttendantConfigs < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_attendant_configs, :behavior_step_mode, :string, null: false, default: 'guide'
  end
end
