# == Schema Information
#
# Table name: contact_pipeline_positions
#
#  id          :bigint           not null, primary key
#  contact_id  :bigint           not null
#  pipeline_id :bigint           not null
#  stage_id    :string           not null
#  deal_value  :decimal(10, 2)
#  entered_at  :datetime
#  metadata    :jsonb            default({})
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_contact_pipeline_positions_contact              (contact_id)
#  idx_contact_pipeline_positions_pipeline             (pipeline_id)
#  idx_contact_pipeline_positions_pipeline_stage       (pipeline_id,stage_id)
#  idx_contact_pipeline_positions_unique                (contact_id,pipeline_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (pipeline_id => custom_attribute_definitions.id)
#

class ContactPipelinePosition < ApplicationRecord
  belongs_to :contact
  belongs_to :pipeline, class_name: 'CustomAttributeDefinition', foreign_key: 'pipeline_id'

  validates :contact_id, presence: true
  validates :pipeline_id, presence: true
  validates :stage_id, presence: true
  validates :contact_id, uniqueness: { scope: :pipeline_id }

  scope :for_pipeline, ->(pipeline_id) { where(pipeline_id: pipeline_id) }
  scope :for_stage, ->(stage_id) { where(stage_id: stage_id) }
  scope :for_contact, ->(contact_id) { where(contact_id: contact_id) }
  scope :ordered, -> { order(:position, :created_at) }
end

