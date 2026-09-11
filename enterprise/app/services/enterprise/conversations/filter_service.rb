module Enterprise::Conversations::FilterService
  def scoped_conversations
    Enterprise::CustomRoleConversationScope.apply(super, user: @user, account: @account)
  end
end
