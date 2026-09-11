module Enterprise::CsatSurveyResponsePolicy
  def index?
    report_manage? || super
  end

  def metrics?
    report_manage? || super
  end

  def download?
    report_manage? || super
  end

  private

  def report_manage?
    @account_user.permissions.include?('report_manage')
  end
end
