# frozen_string_literal: true

class AccountFormPolicy < ApplicationPolicy
  def index?
    administrator? && workflows_enabled?
  end

  def create?
    administrator? && workflows_enabled?
  end

  def show?
    administrator? && workflows_enabled?
  end

  def update?
    administrator? && workflows_enabled?
  end

  def destroy?
    administrator? && workflows_enabled?
  end

  def update_status?
    update?
  end

  def submissions?
    show?
  end

  private

  def administrator?
    @account_user&.administrator?
  end

  def workflows_enabled?
    @account.feature_enabled?('workflows')
  end
end
