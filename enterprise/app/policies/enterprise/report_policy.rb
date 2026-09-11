module Enterprise::ReportPolicy
  def view?
    @account_user.permissions.include?('report_manage') || super
  end
end
