# frozen_string_literal: true

class Api::V1::Accounts::WorkflowEnrollmentSummariesController < Api::V1::Accounts::BaseController
  MAX_CONVERSATION_IDS = 50

  def index
    conversation_ids = Array(params[:conversation_ids]).map(&:to_i).uniq

    if conversation_ids.size > MAX_CONVERSATION_IDS
      return render json: { error: "Maximum #{MAX_CONVERSATION_IDS} conversation_ids allowed" }, status: :unprocessable_entity
    end

    result = Workflows::EnrollmentSummaryService.new(
      account: Current.account,
      user: Current.user,
      conversation_ids: conversation_ids
    ).build

    render json: result
  end
end
