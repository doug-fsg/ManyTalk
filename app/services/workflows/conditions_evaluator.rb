# frozen_string_literal: true

module Workflows
  class ConditionsEvaluator
    pattr_initialize [:account!, :conversation!, :conditions!, :message, :changed_attributes]

    def match?
      return true if conditions.blank?

      rule = ConditionRuleAdapter.new(
        account: account,
        conditions: conditions,
        id: 0
      )
      ::AutomationRules::ConditionsFilterService.new(
        rule,
        conversation,
        { message: message, changed_attributes: changed_attributes }.compact
      ).perform.present?
    rescue StandardError => e
      Rails.logger.error "Workflows::ConditionsEvaluator error: #{e.message}"
      false
    end
  end
end
