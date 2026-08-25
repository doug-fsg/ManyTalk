# frozen_string_literal: true

class Api::V2::Accounts::Reports::WorkflowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    render json: V2::Reports::WorkflowSummaryBuilder.new(
      account: Current.account,
      user: Current.user,
      params: permitted_params
    ).build
  end

  def enrollments
    render json: V2::Reports::WorkflowEnrollmentsBuilder.new(
      account: Current.account,
      user: Current.user,
      params: permitted_params
    ).build
  end

  private

  def check_authorization
    authorize :workflow_report, :view?
  end

  def permitted_params
    params.permit(:since, :until, :workflow_id, :pipeline_id, :stage_id, :page)
  end
end
