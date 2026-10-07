module Enterprise::AccountUser
  def permissions
    custom_role.present? ? (custom_role.permissions + ['custom_role']) : super
  end

  def custom_role_agent?
    agent? && custom_role.present?
  end
end
