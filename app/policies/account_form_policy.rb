# frozen_string_literal: true

class AccountFormPolicy < ApplicationPolicy
  def index?
    account_member? && workflows_enabled?
  end

  def create?
    account_member? && workflows_enabled?
  end

  def show?
    account_member? && workflows_enabled?
  end

  def update?
    account_member? && workflows_enabled?
  end

  def destroy?
    account_member? && workflows_enabled?
  end

  def update_status?
    update?
  end

  def submissions?
    show?
  end

  def export_submissions?
    submissions?
  end

  private

  def account_member?
    @account_user.present?
  end

  def workflows_enabled?
    @account.feature_enabled?('workflows')
  end
end
AccountFormPolicy.prepend_mod_with('AccountFormPolicy')
