module Enterprise::Concerns::KnowledgeBaseCustomRoleAccess
  extend ActiveSupport::Concern

  included do
    const_get(:ACTIONS).each do |method_name|
      define_method(method_name) do |*args, **kwargs, &block|
        custom_role_kb_access? { super(*args, **kwargs, &block) }
      end
    end
  end

  private

  def custom_role_kb_access?
    return yield unless @account_user.custom_role_agent?

    knowledge_base_manage?
  end

  def knowledge_base_manage?
    @account_user.permissions.include?('knowledge_base_manage')
  end
end
