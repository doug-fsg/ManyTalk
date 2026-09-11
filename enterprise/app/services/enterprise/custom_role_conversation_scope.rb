# frozen_string_literal: true

module Enterprise
  class CustomRoleConversationScope
    def self.apply(relation, user:, account:)
      new(relation, user, account).apply
    end

    def initialize(relation, user, account)
      @relation = relation
      @user = user
      @account = account
    end

    def apply
      account_user = @user.current_account_user
      return @relation unless account_user&.custom_role_agent?

      permissions = account_user.custom_role.permissions
      return @relation if permissions.include?('conversation_manage')

      if permissions.include?('conversation_unassigned_manage')
        @relation.unassigned.or(@relation.assigned_to(@user))
      elsif permissions.include?('conversation_participating_manage')
        participant_ids = ConversationParticipant.where(account_id: @account.id, user_id: @user.id).select(:conversation_id)
        @relation.where(assignee_id: @user.id).or(@relation.where(id: participant_ids))
      else
        @relation.none
      end
    end
  end
end
