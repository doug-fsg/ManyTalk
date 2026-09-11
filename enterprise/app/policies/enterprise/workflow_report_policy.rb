module Enterprise::WorkflowReportPolicy
  def view?
    return super unless @account_user.custom_role_agent?

    @account_user.permissions.include?('report_manage')
  end
end
