module Enterprise::ContactPolicy
  %i[
    index?
    show?
    search?
    filter?
    update?
    create?
    avatar?
    contactable_inboxes?
    active?
    destroy_custom_attributes?
  ].each do |method_name|
    define_method(method_name) do |*args, **kwargs, &block|
      custom_role_contact_access? { super(*args, **kwargs, &block) }
    end
  end

  def import?
    contact_manage? || super
  end

  def export?
    contact_manage? || super
  end

  def destroy?
    contact_manage? || super
  end

  private

  def custom_role_contact_access?
    return yield unless @account_user.custom_role_agent?

    contact_manage?
  end

  def contact_manage?
    @account_user.permissions.include?('contact_manage')
  end
end
