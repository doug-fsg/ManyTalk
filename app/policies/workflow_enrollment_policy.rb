# frozen_string_literal: true

class WorkflowEnrollmentPolicy < ApplicationPolicy
  def create?
    account_member? && workflows_enabled?
  end

  def active?
    account_member? && workflows_enabled?
  end

  def pause?
    account_member? && workflows_enabled?
  end

  def resume?
    account_member? && workflows_enabled?
  end

  def cancel?
    account_member? && workflows_enabled?
  end

  def jump?
    account_member? && workflows_enabled?
  end

  private

  def workflows_enabled?
    @account.feature_enabled?('workflows')
  end

  def account_member?
    @account_user.present?
  end
end
