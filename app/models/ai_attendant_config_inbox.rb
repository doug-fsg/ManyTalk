# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_attendant_config_inboxes
#
#  id                     :bigint           not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  ai_attendant_config_id :bigint           not null
#  inbox_id               :integer          not null
#
# Indexes
#
#  index_ai_attendant_config_inboxes_on_ai_attendant_config_id  (ai_attendant_config_id)
#  index_ai_attendant_config_inboxes_on_inbox_id                (inbox_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ai_attendant_config_id => ai_attendant_configs.id)
#
class AiAttendantConfigInbox < ApplicationRecord
  belongs_to :ai_attendant_config
  belongs_to :inbox

  validates :inbox_id, presence: true, uniqueness: true
end
