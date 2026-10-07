# frozen_string_literal: true

module Enterprise::WorkflowSchedulePolicy
  SCHEDULE_ACTIONS = %i[
    index?
    show?
    create?
    update?
    destroy?
    toggle_active?
    audience_count?
  ].freeze

  SCHEDULE_ACTIONS.each do |method_name|
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
