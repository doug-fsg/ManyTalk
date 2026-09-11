module Enterprise::AccountPolicy
  def subscription?
    billing_manage? || super
  end

  def checkout?
    billing_manage? || super
  end

  def limits?
    billing_manage? || super
  end

  private

  def billing_manage?
    @account_user.permissions.include?('billing_manage')
  end
end
