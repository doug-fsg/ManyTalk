module Enterprise::ConversationFinder
  def conversations_base_query
    current_account.feature_enabled?('sla') ? super.includes(:applied_sla, :sla_events) : super
  end

  def find_all_conversations
    super
    @conversations = apply_custom_role_conversation_scope(@conversations)
  end

  private

  def apply_custom_role_conversation_scope(relation)
    Enterprise::CustomRoleConversationScope.apply(relation, user: current_user, account: current_account)
  end
end

