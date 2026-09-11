# frozen_string_literal: true

class WorkflowPolicy < ApplicationPolicy
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

  def clone?
    account_member? && workflows_enabled?
  end

  def toggle_active?
    account_member? && workflows_enabled?
  end

  def dry_run?
    show?
  end

  def test_external_whatsapp?
    account_member? && workflows_enabled?
  end

  def templates?
    create?
  end

  def from_template?
    create?
  end

  def validate?
    create?
  end

  private

  def workflows_enabled?
    @account.feature_enabled?('workflows')
  end

  def account_member?
    @account_user.present?
  end
end
WorkflowPolicy.prepend_mod_with('WorkflowPolicy')
