# frozen_string_literal: true

module WorkflowEnrollment::Lifecycle
  extend ActiveSupport::Concern

  PAUSE_REASONS = %w[manual contact_replied conversation_resolved agent_replied label_applied workflow_inactive].freeze

  included do
    belongs_to :paused_by, class_name: 'User', optional: true
    belongs_to :started_by, class_name: 'User', optional: true

    scope :in_progress, -> { where(status: %w[active waiting paused]) }
    scope :paused, -> { where(status: 'paused') }

    validates :pause_reason, inclusion: { in: PAUSE_REASONS }, allow_nil: true
  end

  def paused?
    status == 'paused'
  end

  def may_pause?
    status.in?(%w[active waiting])
  end

  def may_resume?
    status == 'paused'
  end

  def may_cancel?
    status.in?(%w[active waiting paused])
  end

  def pause!(user: nil, reason:)
    raise "Cannot pause enrollment in status: #{status}" unless may_pause?

    update!(
      status: 'paused',
      paused_at: Time.current,
      paused_by: user,
      pause_reason: reason
    )
  end

  def resume_to_waiting!(resume_at:)
    raise "Cannot resume enrollment in status: #{status}" unless may_resume?

    update!(
      status: 'waiting',
      paused_at: nil,
      paused_by: nil,
      pause_reason: nil,
      resume_at: resume_at
    )
  end

  def resume_to_active!
    raise "Cannot resume enrollment in status: #{status}" unless may_resume?

    update!(
      status: 'active',
      paused_at: nil,
      paused_by: nil,
      pause_reason: nil,
      resume_at: nil
    )
  end
end
