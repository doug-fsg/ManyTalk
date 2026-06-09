# frozen_string_literal: true

class Api::V1::Accounts::Conversations::WorkflowEnrollmentsController < Api::V1::Accounts::Conversations::BaseController
  before_action :set_enrollment, only: %i[pause resume cancel jump rebind]

  def create
    workflow = Current.account.workflows.find(params[:workflow_id])
    result = Workflows::EnrollmentControlService.new.start(
      conversation: @conversation,
      workflow: workflow,
      user: Current.user
    )

    if result[:error] == :conflict
      render json: { error: result[:message] }, status: :conflict
    else
      render json: enrollment_response(result[:enrollment]), status: :created
    end
  end

  def active
    enrollment = @conversation.workflow_enrollments
                            .in_progress
                            .includes(:workflow, :workflow_step_executions)
                            .order(created_at: :desc)
                            .first
    if enrollment
      render json: enrollment_response(enrollment)
    else
      render json: { enrollment: nil }
    end
  end

  def pause
    result = Workflows::EnrollmentControlService.new.pause(
      enrollment: @enrollment,
      user: Current.user,
      reason: params[:reason] || 'manual'
    )
    render_result(result)
  end

  def resume
    result = Workflows::EnrollmentControlService.new.resume(
      enrollment: @enrollment,
      user: Current.user
    )
    render_result(result)
  end

  def cancel
    result = Workflows::EnrollmentControlService.new.cancel(
      enrollment: @enrollment,
      user: Current.user,
      reason: params[:reason] || 'manual'
    )
    render_result(result)
  end

  def jump
    result = Workflows::EnrollmentControlService.new.jump_to_node(
      enrollment: @enrollment,
      node_id: params[:node_id],
      user: Current.user
    )
    render_result(result)
  end

  def rebind
    new_conversation = Current.account.conversations.where(status: 'open').find_by(id: params[:conversation_id])
    return render json: { error: 'conversation_not_found' }, status: :not_found if new_conversation.blank?

    result = Workflows::EnrollmentRebindService.new.rebind(
      enrollment: @enrollment,
      new_conversation: new_conversation,
      user: Current.user
    )

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: enrollment_response(result[:enrollment])
    end
  end

  private

  def set_enrollment
    @enrollment = @conversation.workflow_enrollments.find(params[:id])
  end

  def render_result(result)
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: enrollment_response(result[:enrollment])
    end
  end

  def enrollment_response(enrollment)
    workflow = enrollment.workflow
    current_node = workflow.find_node(enrollment.current_node_id)
    next_execution = enrollment.workflow_step_executions.find { |e| e.status == 'scheduled' }
    timeline_meta = Workflows::TimelineBuilder.new(enrollment).build

    {
      id: enrollment.id,
      workflow_id: enrollment.workflow_id,
      workflow_name: workflow.name,
      conversation_id: enrollment.conversation_id,
      status: enrollment.status,
      current_node_id: enrollment.current_node_id,
      current_node_label: current_node&.dig('data', 'label') || current_node&.dig('type'),
      step_index: timeline_meta[:step_index],
      total_steps: timeline_meta[:total_steps],
      timeline: timeline_meta[:timeline],
      next_scheduled_at: next_execution&.scheduled_at,
      pause_reason: enrollment.pause_reason,
      started_at: enrollment.started_at,
      paused_at: enrollment.paused_at,
      completed_at: enrollment.completed_at,
      cancelled_at: enrollment.cancelled_at,
      started_by: user_payload(enrollment.started_by),
      paused_by: user_payload(enrollment.paused_by),
      available_stages: available_stages(workflow),
      reply_watch: reply_watch_payload(enrollment)
    }
  end

  def reply_watch_payload(enrollment)
    reply_watch = (enrollment.context || {})['reply_watch']
    return nil if reply_watch.blank?

    {
      node_id: reply_watch['node_id'],
      deadline_at: reply_watch['deadline_at'],
      baseline_at: reply_watch['baseline_at']
    }
  end

  def user_payload(user)
    return nil unless user

    { id: user.id, name: user.name }
  end

  def available_stages(workflow)
    (workflow.graph['nodes'] || [])
      .select { |n| n.dig('data', 'label').present? }
      .map { |n| { id: n['id'], label: n.dig('data', 'label'), type: n['type'] } }
  end
end
