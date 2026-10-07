# frozen_string_literal: true

class WorkflowSchedulePolicy < ApplicationPolicy
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

  def toggle_active?
    update?
  end

  def audience_count?
    index?
  end

  private

  def workflows_enabled?
    @account.feature_enabled?('workflows')
  end

  def account_member?
    @account_user.present?
  end
end
WorkflowSchedulePolicy.prepend_mod_with('WorkflowSchedulePolicy')
