# frozen_string_literal: true

# == Schema Information
#
# Table name: workflow_enrollments
#
#  id              :bigint           not null, primary key
#  cancel_reason   :string
#  cancelled_at    :datetime
#  completed_at    :datetime
#  started_at      :datetime
#  status          :string           default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  current_node_id :string
#  workflow_id     :bigint           not null
#
# Indexes
#
#  index_workflow_enrollments_on_account_id                      (account_id)
#  index_workflow_enrollments_on_account_id_and_conversation_id  (account_id,conversation_id)
#  index_workflow_enrollments_on_conversation_id                 (conversation_id)
#  index_workflow_enrollments_on_workflow_id                     (workflow_id)
#  index_workflow_enrollments_unique_active                      (workflow_id,conversation_id) UNIQUE WHERE ((status)::text = ANY ((ARRAY['active'::character varying, 'waiting'::character varying])::text[]))
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (workflow_id => workflows.id)
#
class WorkflowEnrollment < ApplicationRecord
  STATUSES = %w[active waiting completed cancelled].freeze

  belongs_to :workflow
  belongs_to :conversation
  belongs_to :account

  has_many :workflow_step_executions, dependent: :destroy_async

  validates :status, inclusion: { in: STATUSES }

  scope :active_or_waiting, -> { where(status: %w[active waiting]) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }

  def may_run_step?(node_id)
    return false if cancelled? || completed?

    current_node_id.blank? || current_node_id == node_id
  end

  def cancelled?
    status == 'cancelled'
  end

  def completed?
    status == 'completed'
  end

  def waiting?
    status == 'waiting'
  end

  def cancel!(reason)
    with_lock do
      return if cancelled?

      update!(
        status: 'cancelled',
        cancel_reason: reason,
        cancelled_at: Time.current
      )
      workflow_step_executions.where(status: 'scheduled').update_all(status: 'skipped', updated_at: Time.current)
    end
  end

  def complete!
    with_lock do
      update!(status: 'completed', completed_at: Time.current, current_node_id: nil)
    end
  end

  class << self
    def cancel_for_conversation!(conversation, reason:)
      active_or_waiting.where(conversation_id: conversation.id).find_each do |enrollment|
        workflow = enrollment.workflow
        next unless cancel_enabled?(workflow, reason)

        enrollment.cancel!(reason)
      end
    end

    def cancel_enabled?(workflow, reason)
      settings = workflow.settings
      case reason.to_s
      when 'contact_replied'
        settings['cancel_on_contact_reply'] != false
      when 'conversation_resolved'
        settings['cancel_on_conversation_resolved'] != false
      else
        true
      end
    end
  end
end
