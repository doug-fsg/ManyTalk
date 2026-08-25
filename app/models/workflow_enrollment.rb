# frozen_string_literal: true

# == Schema Information
#
# Table name: workflow_enrollments
#
#  id               :bigint           not null, primary key
#  cancel_reason    :string
#  cancelled_at     :datetime
#  completed_at     :datetime
#  context          :jsonb            not null
#  enrollment_scope :string           default("contact"), not null
#  pause_reason     :string
#  paused_at        :datetime
#  resume_at        :datetime
#  started_at       :datetime
#  status           :string           default("active"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  contact_id       :bigint           not null
#  conversation_id  :bigint           not null
#  current_node_id  :string
#  paused_by_id     :bigint
#  started_by_id    :bigint
#  workflow_id      :bigint           not null
#
# Indexes
#
#  idx_we_in_progress_by_account                                 (account_id,status) WHERE ((status)::text = ANY (ARRAY[('active'::character varying)::text, ('waiting'::character varying)::text, ('paused'::character varying)::text]))
#  index_we_on_account_id_and_contact_id                         (account_id,contact_id)
#  index_we_unique_active_contact_scope                          (workflow_id,contact_id) UNIQUE WHERE (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('waiting'::character varying)::text, ('paused'::character varying)::text])) AND ((enrollment_scope)::text = 'contact'::text))
#  index_workflow_enrollments_on_account_id                      (account_id)
#  index_workflow_enrollments_on_account_id_and_conversation_id  (account_id,conversation_id)
#  index_workflow_enrollments_on_contact_id                      (contact_id)
#  index_workflow_enrollments_on_conversation_id                 (conversation_id)
#  index_workflow_enrollments_on_workflow_id                     (workflow_id)
#  index_workflow_enrollments_unique_active                      (workflow_id,conversation_id) UNIQUE WHERE ((status)::text = ANY (ARRAY[('active'::character varying)::text, ('waiting'::character varying)::text, ('paused'::character varying)::text]))
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (paused_by_id => users.id)
#  fk_rails_...  (started_by_id => users.id)
#  fk_rails_...  (workflow_id => workflows.id)
#
class WorkflowEnrollment < ApplicationRecord
  include WorkflowEnrollment::Lifecycle
  include WorkflowEnrollment::ReplyWatch
  include WorkflowEnrollment::IntentWatch
  include WorkflowEnrollment::WatchContext

  STATUSES = %w[active waiting paused completed cancelled].freeze

  belongs_to :workflow
  belongs_to :conversation
  belongs_to :account
  belongs_to :contact, optional: true

  has_many :workflow_step_executions, dependent: :destroy_async

  validates :status, inclusion: { in: STATUSES }
  validates :enrollment_scope, inclusion: { in: Workflows::Constants::ENROLLMENT_SCOPES }, allow_nil: true

  before_validation :sync_contact_from_conversation, on: :create

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
        cancelled_at: Time.current,
        context: (context || {}).except('reply_watch', 'intent_watch')
      )
      workflow_step_executions.where(status: 'scheduled').update_all(status: 'skipped', updated_at: Time.current)
    end
  end

  def complete!
    with_lock do
      update!(
        status: 'completed',
        completed_at: Time.current,
        current_node_id: nil,
        context: (context || {}).except('reply_watch', 'intent_watch')
      )
    end
  end

  def sync_contact_from_conversation
    self.contact_id ||= conversation&.contact_id
    self.enrollment_scope ||= Workflows::Constants::DEFAULT_SETTINGS['enrollment_scope']
  end

  class << self
    def handle_contact_reply!(conversation)
      handle_reply!(conversation, nil)
    end

    def handle_reply!(conversation, message)
      Workflows::EnrollmentFollowService.follow_to_conversation!(conversation)
      enrollments_for_conversation(conversation).find_each do |enrollment|
        Workflows::EnrollmentControlService.new.handle_reply(enrollment.reload, message)
      end
    end

    def enrollments_for_conversation(conversation)
      by_conversation = in_progress.where(conversation_id: conversation.id)
      return by_conversation if conversation.contact_id.blank?

      by_contact = in_progress.where(contact_id: conversation.contact_id, enrollment_scope: 'contact')
      by_conversation.or(by_contact)
    end

    def cancel_for_conversation!(conversation, reason:)
      in_progress.where(conversation_id: conversation.id).find_each do |enrollment|
        next unless cancel_enabled?(enrollment.workflow, reason)

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
      when 'agent_replied'
        settings['cancel_on_agent_reply'] == true
      else
        true
      end
    end

    def cancel_for_agent_reply!(conversation)
      enrollments_for_conversation(conversation).find_each do |enrollment|
        next unless cancel_enabled?(enrollment.workflow, 'agent_replied')

        enrollment.cancel!('agent_replied')
      end
    end

    def cancel_for_labels!(conversation, labels)
      return if labels.blank?

      enrollments_for_conversation(conversation).find_each do |enrollment|
        cancel_labels = Array(enrollment.workflow.settings['cancel_on_labels'])
        next if cancel_labels.blank?
        next unless (cancel_labels & labels.map(&:to_s)).any?

        enrollment.cancel!('label_applied')
      end
    end
  end
end
