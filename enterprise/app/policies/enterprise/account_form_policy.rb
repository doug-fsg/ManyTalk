module Enterprise::AccountFormPolicy
  FORM_ACTIONS = %i[
    index?
    show?
    create?
    update?
    destroy?
    update_status?
    submissions?
    export_submissions?
  ].freeze

  FORM_ACTIONS.each do |method_name|
    define_method(method_name) do |*args, **kwargs, &block|
      custom_role_allows? { super(*args, **kwargs, &block) }
    end
  end

  private

  def custom_role_allows?
    return yield unless @account_user.custom_role_agent?

    @account_user.permissions.intersect?(%w[form_manage workflow_manage]) && yield
  end
end
