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
#  behavior_step_mode       :string           default("guide"), not null
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
#  avatar_id                :string           default("avatar_1"), not null
#  many_ia_config_id        :string
#  sender_user_id           :bigint
#
# Indexes
#
#  index_ai_attendant_configs_on_account_id      (account_id)
#  index_ai_attendant_configs_on_sender_user_id  (sender_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (sender_user_id => users.id)
#
class AiAttendantConfig < ApplicationRecord
  SCHEDULE_MODES = %w[always within_inbox_hours outside_inbox_hours].freeze
  PAUSE_REASONS = %w[no_credits admin].freeze
  BEHAVIOR_STEP_MODES = AiAttendant::BehaviorScript::STEP_MODES

  belongs_to :account
  belongs_to :sender_user, class_name: 'User', optional: true
  has_many :ai_attendant_config_inboxes, dependent: :destroy
  has_many :inboxes, through: :ai_attendant_config_inboxes
  has_many_attached :reference_files

  validate :must_have_at_least_one_inbox_link, on: :update
  validates :avatar_id, presence: true, inclusion: { in: AiAttendant::Avatars::IDS }
  validates :schedule_mode, inclusion: { in: SCHEDULE_MODES }
  validates :pause_reason, inclusion: { in: PAUSE_REASONS }, allow_nil: true
  validates :debounce_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 30 }
  validates :behavior_step_mode, inclusion: { in: BEHAVIOR_STEP_MODES }

  before_validation :normalize_behavior_steps_storage

  scope :for_inbox, lambda { |inbox_id|
    joins(:ai_attendant_config_inboxes).where(ai_attendant_config_inboxes: { inbox_id: inbox_id })
  }

  def inbox_ids
    ai_attendant_config_inboxes.pluck(:inbox_id)
  end

  def primary_inbox_id
    inbox_ids.first
  end

  def avatar_url
    AiAttendant::Avatars.url_for(avatar_id)
  end

  private

  def must_have_at_least_one_inbox_link
    return if ai_attendant_config_inboxes.any?

    errors.add(:base, :inbox_required)
  end

  def normalize_behavior_steps_storage
    self.behavior_steps = AiAttendant::BehaviorScript.normalize_steps(behavior_steps).map(&:to_h)
  end
end
