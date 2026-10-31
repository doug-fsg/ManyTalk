# frozen_string_literal: true

class RenameAiAttendantAvatarIds < ActiveRecord::Migration[7.0]
  LEGACY_MAP = {
    'woman_1' => 'avatar_1',
    'woman_2' => 'avatar_2',
    'woman_3' => 'avatar_3',
    'man_1' => 'avatar_4',
    'man_2' => 'avatar_5',
    'man_3' => 'avatar_6'
  }.freeze

  def up
    LEGACY_MAP.each do |legacy, current|
      execute <<~SQL.squish
        UPDATE ai_attendant_configs SET avatar_id = '#{current}' WHERE avatar_id = '#{legacy}'
      SQL
    end
    change_column_default :ai_attendant_configs, :avatar_id, from: 'woman_1', to: 'avatar_1'
  end

  def down
    LEGACY_MAP.each do |legacy, current|
      execute <<~SQL.squish
        UPDATE ai_attendant_configs SET avatar_id = '#{legacy}' WHERE avatar_id = '#{current}'
      SQL
    end
    change_column_default :ai_attendant_configs, :avatar_id, from: 'avatar_1', to: 'woman_1'
  end
end
