# frozen_string_literal: true

class Api::V1::Accounts::WorkflowEnrollmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_workflow

  def index
    authorize @workflow
    @enrollments = @workflow.workflow_enrollments.order(created_at: :desc).limit(100)
  end

  private

  def fetch_workflow
    @workflow = Current.account.workflows.find(params[:workflow_id])
  end
end
