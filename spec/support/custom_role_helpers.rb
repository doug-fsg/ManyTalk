# frozen_string_literal: true

module CustomRoleHelpers
  def enable_custom_roles!(account)
    account.enable_features!('custom_roles')
  end

  def create_custom_role_agent(account, permissions)
    enable_custom_roles!(account)
    user = create(:user, account: account, role: :agent)
    custom_role = create(:custom_role, account: account, permissions: Array(permissions))
    account_user_for(user, account).update!(custom_role: custom_role)
    user
  end

  def account_user_for(user, account = nil)
    target_account_id = account&.id || Current.account&.id
    if target_account_id
      user.account_users.find { |account_user| account_user.account_id == target_account_id }
    else
      user.account_users.first
    end
  end

  def policy_context(user, account = Current.account)
    {
      user: user,
      account: account,
      account_user: account_user_for(user, account)
    }
  end
end

RSpec.configure do |config|
  config.include CustomRoleHelpers
end
