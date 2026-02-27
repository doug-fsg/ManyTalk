class Api::V1::Accounts::ActivitiesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @activities = Current.account.activities
                         .includes(:user, :assignee, :contact, :conversation, :inbox)
                         .ordered

    # Filtros
    @activities = @activities.where(status: params[:status]) if params[:status].present?
    @activities = @activities.where(activity_type: params[:activity_type]) if params[:activity_type].present?
    @activities = @activities.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    if params[:contact_ids].present?
      ids = params[:contact_ids].is_a?(Array) ? params[:contact_ids] : params[:contact_ids].to_s.split(',').map(&:to_i)
      @activities = @activities.where(contact_id: ids) if ids.any?
    elsif params[:contact_id].present?
      @activities = @activities.where(contact_id: params[:contact_id])
    end
  end

  def show
    @activity = Current.account.activities.find(params[:id])
  end

  def create
    @activity = Activities::CreateService.new(
      user: Current.user,
      account: Current.account,
      params: activity_params
    ).perform
  end

  def update
    @activity = Current.account.activities.find(params[:id])
    @activity.update!(activity_params)
  end

  def destroy
    @activity = Current.account.activities.find(params[:id])
    @activity.cancel!
    head :no_content
  end

  def complete
    @activity = Current.account.activities.find(params[:id])
    @activity.complete!
  end

  private

  def activity_params
    params.require(:activity).permit(
      :activity_type, :title, :description, :scheduled_at,
      :assignee_id, :contact_id, :conversation_id,
      :contact_pipeline_position_id, :message_content, :inbox_id
    )
  end

  def check_authorization
    authorize(Activity)
  end
end

