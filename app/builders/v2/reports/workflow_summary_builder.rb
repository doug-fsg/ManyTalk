# frozen_string_literal: true

class V2::Reports::WorkflowSummaryBuilder
  include DateRangeHelper

  attr_reader :account, :user, :params

  def initialize(account:, user:, params:)
    @account = account
    @user = user
    @params = params
  end

  def build
    {
      summary: summary_metrics,
      steps: step_metrics
    }
  end

  private

  def summary_metrics
    historical = scoped_enrollments.to_a
    total = historical.size
    replied = historical.count { |e| contact_replied_during?(e) }

    {
      active_count: active_enrollments_count,
      completed_count: historical.count { |e| e.status == 'completed' },
      cancelled_count: historical.count { |e| e.status == 'cancelled' },
      reply_rate: total.positive? ? (replied.to_f / total * 100).round(1) : 0,
      avg_time_to_reply_seconds: average_reply_seconds(historical)
    }
  end

  def step_metrics
    workflow = selected_workflow
    return [] if workflow.blank?

    send_nodes(workflow).map do |node|
      node_id = node['id']
      label = node.dig('data', 'label') || node_id
      executions = completed_executions_for(workflow, node_id)
      sent_count = executions.size
      reply_count = executions.count { |e| execution_replied?(e) }

      {
        node_id: node_id,
        label: label,
        sent_count: sent_count,
        reply_count: reply_count,
        reply_rate: sent_count.positive? ? (reply_count.to_f / sent_count * 100).round(1) : 0
      }
    end
  end

  def active_enrollments_count
    scope = account.workflow_enrollments.in_progress
    scope = scope.joins(:conversation).where(conversations: { inbox_id: assigned_inbox_ids }) unless administrator?
    scope.count
  end

  def scoped_enrollments
    scope = account.workflow_enrollments.includes(:conversation).where(created_at: range)
    unless administrator?
      scope = scope.joins(:conversation).where(conversations: { inbox_id: assigned_inbox_ids })
    end
    scope = scope.where(workflow_id: params[:workflow_id]) if params[:workflow_id].present?
    scope
  end

  def assigned_inbox_ids
    @assigned_inbox_ids ||= user.assigned_inboxes.where(account_id: account.id).pluck(:id)
  end

  def administrator?
    account.account_users.find_by(user_id: user.id)&.administrator?
  end

  def selected_workflow
    return account.workflows.find_by(id: params[:workflow_id]) if params[:workflow_id].present?

    account.workflows.order(updated_at: :desc).first
  end

  def send_nodes(workflow)
    (workflow.graph['nodes'] || []).select do |node|
      node['type'] == 'action' && node.dig('data', 'action_name') == 'send_message'
    end
  end

  def completed_executions_for(workflow, node_id)
    WorkflowStepExecution.joins(:workflow_enrollment)
                         .includes(workflow_enrollment: :conversation)
                         .where(
                           workflow_enrollments: {
                             account_id: account.id,
                             workflow_id: workflow.id,
                             created_at: range
                           },
                           node_id: node_id,
                           status: 'completed'
                         )
                         .to_a
  end

  def contact_replied_during?(enrollment)
    return false if enrollment.started_at.blank?

    enrollment.conversation.messages.incoming
              .where('messages.created_at >= ?', enrollment.started_at)
              .exists?
  end

  def execution_replied?(execution)
    return execution.metadata['replied'] == true if execution.metadata['replied'].present?

    enrollment = execution.workflow_enrollment
    return false if enrollment.started_at.blank? || execution.executed_at.blank?

    enrollment.conversation.messages.incoming
              .where('messages.created_at >= ?', execution.executed_at)
              .exists?
  end

  def average_reply_seconds(enrollments)
    durations = enrollments.filter_map do |enrollment|
      next if enrollment.started_at.blank?

      first_reply = enrollment.conversation.messages.incoming
                              .where('messages.created_at >= ?', enrollment.started_at)
                              .order(:created_at)
                              .first
      next if first_reply.blank?

      (first_reply.created_at - enrollment.started_at).to_i
    end

    return 0 if durations.blank?

    (durations.sum / durations.size.to_f).round
  end
end
