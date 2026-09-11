module Enterprise::CategoryPolicy
  include Enterprise::Concerns::KnowledgeBaseCustomRoleAccess

  ACTIONS = %i[index? show? edit? update? create? destroy?].freeze
end
