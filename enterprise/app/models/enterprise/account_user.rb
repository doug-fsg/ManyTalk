module Enterprise::AccountUser
  def permissions
    custom_role_agent? ? custom_role.permissions + ['custom_role'] : super
  end

  def custom_role_agent?
    agent? && custom_role.present? && custom_roles_enabled?
  end

  private

  def custom_roles_enabled?
    (Current.account&.id == account_id ? Current.account : account).feature_enabled?('custom_roles')
  end
end
