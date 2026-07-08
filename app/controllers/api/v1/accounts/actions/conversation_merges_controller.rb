# frozen_string_literal: true

class Api::V1::Accounts::Actions::ConversationMergesController < Api::V1::Accounts::BaseController
  before_action :set_base_conversation, only: [:create]
  before_action :set_mergee_conversation, only: [:create]

  rescue_from CustomExceptions::ConversationMerge::InvalidMerge, with: :render_invalid_merge_error

  def create
    @base_conversation = ConversationMergeAction.new(
      account: Current.account,
      base_conversation: @base_conversation,
      mergee_conversation: @mergee_conversation
    ).perform
  end

  private

  def set_base_conversation
    @base_conversation = conversations.find_by!(display_id: params[:base_conversation_id])
  end

  def set_mergee_conversation
    @mergee_conversation = conversations.find_by!(display_id: params[:mergee_conversation_id])
  end

  def conversations
    @conversations ||= Current.account.conversations
  end

  def render_invalid_merge_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
