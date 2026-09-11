module Enterprise::ArticlePolicy
  include Enterprise::Concerns::KnowledgeBaseCustomRoleAccess

  ACTIONS = %i[index? show? edit? update? create? destroy? reorder?].freeze

  knowledge_base_actions ACTIONS
end
