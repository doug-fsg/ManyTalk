module Enterprise::AutomationRulePolicy
  def index? = automation_manage? || super
  def create? = automation_manage? || super
  def show? = automation_manage? || super
  def update? = automation_manage? || super
  def clone? = automation_manage? || super
  def destroy? = automation_manage? || super

  private

  def automation_manage?
    @account_user.permissions.include?('automation_manage')
  end
end
