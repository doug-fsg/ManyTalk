# frozen_string_literal: true

# == Schema Information
#
# Table name: contact_pipeline_events
#
#  id                           :bigint           not null, primary key
#  event_type                   :string           not null
#  from_stage_id                :string
#  metadata                     :jsonb            not null
#  occurred_at                  :datetime         not null
#  to_stage_id                  :string
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  contact_id                   :bigint           not null
#  contact_pipeline_position_id :bigint           not null
#  pipeline_id                  :bigint           not null
#  user_id                      :bigint
#
class ContactPipelineEvent < ApplicationRecord
  EVENT_TYPES = %w[entered stage_changed won lost win_lost_cleared].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :contact_pipeline_position
  belongs_to :user, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :pipeline_id, presence: true
  validates :occurred_at, presence: true

  scope :for_contact, ->(contact_id) { where(contact_id: contact_id) }
  scope :chronological, -> { order(occurred_at: :desc, id: :desc) }
end
