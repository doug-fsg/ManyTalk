# frozen_string_literal: true

class ActivityPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.where(account_id: account.id)
      return base if account_user.administrator?

      base.where('assignee_id = :user_id OR user_id = :user_id', user_id: user.id)
    end
  end

  def index?
    user.present?
  end

  def show?
    administrator? || owner_or_assignee?
  end

  def create?
    user.present?
  end

  def update?
    administrator? || owner_or_assignee?
  end

  def destroy?
    administrator? || owner_or_assignee?
  end

  def complete?
    update?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def owner_or_assignee?
    record.user_id == user.id || record.assignee_id == user.id
  end
end
