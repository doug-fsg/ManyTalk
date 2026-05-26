# frozen_string_literal: true

class Api::V1::Accounts::WorkflowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_workflow, only: [:show, :update, :destroy, :clone, :toggle_active]

  def index
    @workflows = Current.account.workflows.order(updated_at: :desc)
  end

  def show; end

  def create
    result = Workflows::CreateService.new(
      account: Current.account,
      user: current_user,
      params: workflow_params
    ).perform

    if result[:workflow].present?
      @workflow = result[:workflow]
    else
      render json: { error: result[:errors] }, status: :unprocessable_entity
    end
  end

  def update
    result = Workflows::UpdateService.new(
      workflow: @workflow,
      user: current_user,
      params: workflow_params
    ).perform

    if result[:errors].blank?
      @workflow = result[:workflow]
    else
      render json: { error: result[:errors] }, status: :unprocessable_entity
    end
  end

  def destroy
    @workflow.workflow_enrollments.active_or_waiting.find_each(&:cancel!)
    @workflow.update!(active: false)
    @workflow.destroy!
    head :ok
  end

  def clone
    source = Current.account.workflows.find(params[:id])
    @workflow = source.dup
    @workflow.name = "#{source.name} (copy)"
    @workflow.active = false
    @workflow.created_by = current_user
    @workflow.updated_by = current_user
    @workflow.save!
  end

  def toggle_active
    @workflow.update!(active: !@workflow.active, updated_by: current_user)
    @workflow
  end

  private

  def workflow_params
    base = params.permit(:name, :description, :active).to_h
    base['graph'] = Workflows::GraphParamsParser.to_hash(params[:graph]) if params[:graph].present?
    base.with_indifferent_access
  end

  def fetch_workflow
    @workflow = Current.account.workflows.find(params[:id])
  end
end
