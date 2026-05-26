# frozen_string_literal: true

module Workflows
  # Duck-type adapter so AutomationRules::ConditionsFilterService can evaluate workflow node conditions.
  class ConditionRuleAdapter
    attr_reader :conditions, :id, :account

    def initialize(account:, conditions:, id: 0)
      @account = account
      @conditions = conditions || []
      @id = id
    end

    def authorization_error!
      nil
    end
  end
end
