# frozen_string_literal: true

# == Schema Information
#
# Table name: workflow_step_executions
#
#  id                     :bigint           not null, primary key
#  error_message          :text
#  executed_at            :datetime
#  metadata               :jsonb            not null
#  scheduled_at           :datetime
#  status                 :string           default("scheduled"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  job_id                 :string
#  node_id                :string           not null
#  workflow_enrollment_id :bigint           not null
#
# Indexes
#
#  index_wse_on_enrollment_id        (workflow_enrollment_id)
#  index_wse_unique_enrollment_node  (workflow_enrollment_id,node_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (workflow_enrollment_id => workflow_enrollments.id)
#
class WorkflowStepExecution < ApplicationRecord
  STATUSES = %w[scheduled running completed skipped failed].freeze

  belongs_to :workflow_enrollment

  validates :node_id, presence: true
  validates :status, inclusion: { in: STATUSES }
end
