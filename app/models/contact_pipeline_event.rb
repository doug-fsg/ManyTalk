# frozen_string_literal: true

# == Schema Information
#
# Table name: contact_pipeline_events
#
#  id                           :bigint           not null, primary key
#  event_type                   :string           not null
#  metadata                     :jsonb            not null
#  occurred_at                  :datetime         not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  contact_id                   :bigint           not null
#  contact_pipeline_position_id :bigint           not null
#  from_stage_id                :string
#  pipeline_id                  :bigint           not null
#  to_stage_id                  :string
#  user_id                      :bigint
#
# Indexes
#
#  index_contact_pipeline_events_on_account_and_occurred_at       (account_id,occurred_at)
#  index_contact_pipeline_events_on_account_id                    (account_id)
#  index_contact_pipeline_events_on_contact_and_occurred_at       (contact_id,occurred_at)
#  index_contact_pipeline_events_on_contact_id                    (contact_id)
#  index_contact_pipeline_events_on_contact_pipeline_position_id  (contact_pipeline_position_id)
#  index_contact_pipeline_events_on_event_type                    (event_type)
#  index_contact_pipeline_events_on_pipeline_id                   (pipeline_id)
#  index_contact_pipeline_events_on_position_and_occurred_at      (contact_pipeline_position_id,occurred_at)
#  index_contact_pipeline_events_on_user_id                       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (contact_pipeline_position_id => contact_pipeline_positions.id)
#  fk_rails_...  (user_id => users.id)
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
