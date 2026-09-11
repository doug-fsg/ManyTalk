module Enterprise::Api::V1::Accounts::AgentsController
  def create
    super
    apply_custom_role
  end

  def update
    params[:agent]&.delete(:custom_role_id) unless Current.account.feature_enabled?('custom_roles')
    super
  end

  private

  def apply_custom_role
    return if @agent.blank?
    return unless Current.account.feature_enabled?('custom_roles')
    return unless params.dig(:agent, :custom_role_id) || params[:custom_role_id]

    @agent.current_account_user.update!(custom_role_id: params.dig(:agent, :custom_role_id) || params[:custom_role_id])
  end
end
