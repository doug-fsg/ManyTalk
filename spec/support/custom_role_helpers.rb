# frozen_string_literal: true

module CustomRoleHelpers
  def enable_custom_roles!(account)
    account.enable_features!('custom_roles')
  end

  def create_custom_role_agent(account, permissions)
    enable_custom_roles!(account)
    user = create(:user, account: account, role: :agent)
    custom_role = create(:custom_role, account: account, permissions: Array(permissions))
    user.current_account_user.update!(custom_role: custom_role)
    user
  end

  def account_user_for(user)
    user.current_account_user
  end
end

RSpec.configure do |config|
  config.include CustomRoleHelpers
end
