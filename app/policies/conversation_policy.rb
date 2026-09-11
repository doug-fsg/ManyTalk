class ConversationPolicy < ApplicationPolicy
  def index?
    user.present? && (record.assignee == user || record.team.members.include?(user))
  end

  def show?
    true
  end
end
ConversationPolicy.prepend_mod_with('ConversationPolicy')
