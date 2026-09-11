module Enterprise::PortalPolicy
  include Enterprise::Concerns::KnowledgeBaseCustomRoleAccess

  ACTIONS = %i[index? show? edit? update? create? destroy? add_members? logo?].freeze

  knowledge_base_actions ACTIONS
end
