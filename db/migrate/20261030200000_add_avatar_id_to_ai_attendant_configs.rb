# frozen_string_literal: true

class AddAvatarIdToAiAttendantConfigs < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_attendant_configs, :avatar_id, :string, null: false, default: 'avatar_1'
  end
end
