# frozen_string_literal: true

class Api::V1::Accounts::ActivitiesController < Api::V1::Accounts::BaseController
  before_action :check_authorization, only: [:index]
  before_action :set_activity, only: [:show, :update, :destroy, :complete]

  RESULTS_PER_PAGE = 25
  MAX_RANGE_RESULTS = 500

  def index
    @activities = policy_scope(Current.account.activities)
                 .includes(:user, :assignee, :contact, :conversation, :inbox, contact_pipeline_position: :pipeline)
                 .ordered

    @activities = apply_filters(@activities)
    @activities_count = @activities.count

    @activities = if date_range_filter?
                    @activities.limit(MAX_RANGE_RESULTS)
                  else
                    @activities.page(current_page).per(per_page)
                  end
  end

  def show
    authorize @activity
  end

  def create
    authorize Activity
    @activity = Activities::CreateService.new(
      user: Current.user,
      account: Current.account,
      params: activity_params
    ).perform
  end

  def update
    authorize @activity
    @activity.update!(activity_params)
  end

  def destroy
    authorize @activity
    @activity.destroy!
    head :no_content
  end

  def complete
    authorize @activity
    @activity.complete!
  end

  private

  def set_activity
    @activity = policy_scope(Current.account.activities).find(params[:id])
  end

  def apply_filters(relation)
    relation = apply_status_filter(relation)
    relation = relation.where(activity_type: params[:activity_type]) if params[:activity_type].present?
    relation = relation.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    relation = relation.where(user_id: params[:user_id]) if params[:user_id].present?

    if params[:contact_ids].present?
      ids = params[:contact_ids].is_a?(Array) ? params[:contact_ids] : params[:contact_ids].to_s.split(',').map(&:to_i)
      relation = relation.where(contact_id: ids) if ids.any?
    elsif params[:contact_id].present?
      relation = relation.where(contact_id: params[:contact_id])
    end

    relation = apply_scheduled_range_filter(relation)
    relation
  end

  def apply_status_filter(relation)
    return relation unless params[:status].present?

    if params[:status] == 'overdue'
      relation.pending.where('scheduled_at < ?', Time.current)
    else
      relation.where(status: params[:status])
    end
  end

  def apply_scheduled_range_filter(relation)
    if params[:scheduled_from].present?
      relation = relation.where('scheduled_at >= ?', Time.zone.parse(params[:scheduled_from]))
    end
    if params[:scheduled_to].present?
      relation = relation.where('scheduled_at <= ?', Time.zone.parse(params[:scheduled_to]))
    end
    relation
  end

  def date_range_filter?
    params[:scheduled_from].present? || params[:scheduled_to].present?
  end

  def current_page
    params[:page].presence || 1
  end

  def per_page
    n = params[:per_page].to_i
    n.positive? ? [n, MAX_RANGE_RESULTS].min : RESULTS_PER_PAGE
  end

  def activity_params
    permitted = params.require(:activity).permit(
      :activity_type, :title, :description, :scheduled_at,
      :assignee_id, :contact_id, :conversation_id,
      :contact_pipeline_position_id, :message_content, :inbox_id
    )
    permitted[:metadata] = params[:activity][:metadata].to_unsafe_h if params[:activity][:metadata].present?
    permitted
  end

  def check_authorization
    authorize(Activity)
  end
end
