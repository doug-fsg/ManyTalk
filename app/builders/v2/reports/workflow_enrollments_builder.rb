# frozen_string_literal: true

class V2::Reports::WorkflowEnrollmentsBuilder
  include DateRangeHelper

  PAGE_SIZE = 25

  attr_reader :account, :user, :params

  def initialize(account:, user:, params:)
    @account = account
    @user = user
    @params = params
  end

  def build
    records = paginated_enrollments
    {
      payload: records.map { |enrollment| serialize(enrollment) },
      meta: {
        count: scoped_enrollments.count,
        current_page: page
      }
    }
  end

  private

  def paginated_enrollments
    scoped_enrollments
      .includes(:contact, :workflow, :started_by, conversation: :assignee)
      .order(created_at: :desc)
      .page(page)
      .per(PAGE_SIZE)
  end

  def scoped_enrollments
    scope = account.workflow_enrollments
    scope = apply_date_scope(scope)
    unless administrator?
      scope = scope.joins(:conversation).where(conversations: { inbox_id: assigned_inbox_ids })
    end
    scope = scope.where(workflow_id: params[:workflow_id]) if params[:workflow_id].present?
    scope
  end

  def apply_date_scope(scope)
    return scope if range.blank?

    in_range = scope.where(workflow_enrollments: { created_at: range })
    still_active = scope.where(status: %w[active waiting paused])
                        .where('workflow_enrollments.created_at <= ?', range.end)
    in_range.or(still_active)
  end

  def serialize(enrollment)
    conversation = enrollment.conversation
    workflow = enrollment.workflow
    node = workflow&.find_node(enrollment.current_node_id)

    {
      id: enrollment.id,
      status: enrollment.status,
      current_node_label: Workflows::NodeLabel.for_node(node),
      started_at: enrollment.started_at&.to_i || enrollment.created_at.to_i,
      conversation_id: conversation&.display_id,
      conversation_status: conversation&.status,
      workflow_id: enrollment.workflow_id,
      workflow_name: workflow&.name,
      contact: person_payload(enrollment.contact),
      assigned_agent: person_payload(conversation&.assignee),
      started_by: person_payload(enrollment.started_by)
    }
  end

  def person_payload(record)
    return nil if record.blank?

    {
      id: record.id,
      name: record.try(:available_name).presence || record.name,
      thumbnail: record.try(:avatar_url),
      availability_status: record.try(:availability_status)
    }
  end

  def page
    [params[:page].to_i, 1].max
  end

  def assigned_inbox_ids
    @assigned_inbox_ids ||= user.assigned_inboxes.where(account_id: account.id).pluck(:id)
  end

  def administrator?
    account.account_users.find_by(user_id: user.id)&.administrator?
  end
end
