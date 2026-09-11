module Enterprise::WorkflowPolicy
  WORKFLOW_ACTIONS = %i[
    index?
    show?
    create?
    update?
    destroy?
    clone?
    toggle_active?
    from_template?
    validate?
    test_external_whatsapp?
    dry_run?
    templates?
  ].freeze

  WORKFLOW_ACTIONS.each do |method_name|
    define_method(method_name) do |*args, **kwargs, &block|
      custom_role_allows?('workflow_manage') { super(*args, **kwargs, &block) }
    end
  end

  private

  def custom_role_allows?(permission)
    return yield unless @account_user.custom_role_agent?

    @account_user.permissions.include?(permission) && yield
  end
end
