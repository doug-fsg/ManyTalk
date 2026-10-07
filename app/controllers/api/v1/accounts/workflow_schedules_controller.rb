# frozen_string_literal: true

class Api::V1::Accounts::WorkflowSchedulesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_schedule, only: [:show, :update, :destroy, :toggle_active]

  def index
    @workflow_schedules = Current.account.workflow_schedules
                                 .includes(:workflow, :pipeline)
                                 .order(updated_at: :desc)
    @audience_counts = WorkflowSchedule.audience_counts_for(@workflow_schedules)
  end

  def show; end

  def create
    @workflow_schedule = Current.account.workflow_schedules.new(schedule_params)
    @workflow_schedule.created_by = current_user
    if @workflow_schedule.save
      render :show
    else
      render json: { error: @workflow_schedule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @workflow_schedule.update(schedule_params)
      render :show
    else
      render json: { error: @workflow_schedule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @workflow_schedule.destroy!
    head :ok
  end

  def toggle_active
    @workflow_schedule.update!(active: !@workflow_schedule.active)
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def audience_count
    count = ContactPipelinePosition
            .joins(:contact)
            .where(
              contacts: { account_id: Current.account.id },
              pipeline_id: params[:pipeline_id],
              stage_id: params[:stage_id]
            )
            .count
    render json: { count: count }
  end

  private

  def fetch_schedule
    @workflow_schedule = Current.account.workflow_schedules.find(params[:id])
  end

  def schedule_params
    params.permit(
      :name,
      :workflow_id,
      :pipeline_id,
      :stage_id,
      :weekday,
      :hour,
      :minute,
      :time_zone,
      :active,
      :recurring,
      :next_run_at
    )
  end
end
