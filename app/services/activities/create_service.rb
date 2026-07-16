class Activities::CreateService
  def initialize(user:, account:, params:)
    @user = user
    @account = account
    @params = params
  end

  def perform
    @account.activities.create!(
      user: @user,
      assignee_id: @params[:assignee_id] || @user.id,
      activity_type: @params[:activity_type],
      title: @params[:title],
      description: @params[:description],
      scheduled_at: @params[:scheduled_at],
      contact_pipeline_position_id: @params[:contact_pipeline_position_id],
      contact_id: @params[:contact_id],
      conversation_id: @params[:conversation_id],
      inbox_id: @params[:inbox_id],
      message_content: @params[:message_content],
      metadata: @params[:metadata] || {}
    )
  end
end

