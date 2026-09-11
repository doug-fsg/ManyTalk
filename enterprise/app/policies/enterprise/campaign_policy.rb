module Enterprise::CampaignPolicy
  CAMPAIGN_ACTIONS = %i[
    index?
    show?
    create?
    update?
    destroy?
    progress?
    retry_failed?
    pause?
    stop?
    resume?
    resend?
  ].freeze

  CAMPAIGN_ACTIONS.each do |method_name|
    define_method(method_name) do |*args, **kwargs, &block|
      custom_role_allows? { super(*args, **kwargs, &block) }
    end
  end

  private

  def custom_role_allows?
    return yield unless @account_user.custom_role_agent?

    @account_user.permissions.include?('campaign_manage') && yield
  end
end
