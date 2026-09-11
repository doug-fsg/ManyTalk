module Enterprise::ConversationPolicy
  def show?
    return true unless @account_user&.custom_role_agent?

    permissions = @account_user.custom_role.permissions
    return true if permissions.include?('conversation_manage')
    return unassigned_or_mine? if permissions.include?('conversation_unassigned_manage')
    return mine_or_participant? if permissions.include?('conversation_participating_manage')

    false
  end

  private

  def unassigned_or_mine?
    record.assignee_id.nil? || record.assignee_id == user.id
  end

  def mine_or_participant?
    record.assignee_id == user.id || record.conversation_participants.exists?(user_id: user.id)
  end
end
