# frozen_string_literal: true

class WorkflowReportPolicy < ApplicationPolicy
  def view?
    @account_user.present?
  end
end
WorkflowReportPolicy.prepend_mod_with('WorkflowReportPolicy')
