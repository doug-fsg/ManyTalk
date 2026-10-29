# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_attendant_configs
#
#  id                       :bigint           not null, primary key
#  active                   :boolean          default(FALSE), not null
#  agent_duties             :text
#  agent_objective          :text
#  agent_role               :text
#  behavior_steps           :jsonb            not null
#  company_context          :text
#  debounce_seconds         :integer          default(5), not null
#  detect_language          :boolean          default(FALSE), not null
#  digital_agent_name       :string
#  handoff_conditions       :text
#  handoff_customer_message :text
#  pause_reason             :string
#  schedule_mode            :string           default("always"), not null
#  topics_to_avoid          :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  inbox_id                 :integer          not null
#  many_ia_config_id        :string
#  sender_user_id           :bigint
#
# Indexes
#
#  index_ai_attendant_configs_on_account_id               (account_id)
#  index_ai_attendant_configs_on_account_id_and_inbox_id  (account_id,inbox_id) UNIQUE
#  index_ai_attendant_configs_on_sender_user_id           (sender_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (sender_user_id => users.id)
#
class AiAttendantConfig < ApplicationRecord
  SCHEDULE_MODES = %w[always within_inbox_hours outside_inbox_hours].freeze
  PAUSE_REASONS = %w[no_credits admin].freeze

  belongs_to :account
  belongs_to :sender_user, class_name: 'User', optional: true
  has_many_attached :reference_files

  validates :inbox_id, presence: true, uniqueness: { scope: :account_id }
  validates :schedule_mode, inclusion: { in: SCHEDULE_MODES }
  validates :pause_reason, inclusion: { in: PAUSE_REASONS }, allow_nil: true
  validates :debounce_seconds, numericality: { less_than_or_equal_to: 30 }

  scope :for_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
end
