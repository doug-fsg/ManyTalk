# frozen_string_literal: true

module Workflows
  class ConditionsEvaluator
    KANBAN_ATTRIBUTE_KEYS = %w[kanban_pipeline_id kanban_stage_id].freeze

    REPLY_ATTRIBUTE_KEYS = %w[contact_replied_since_baseline contact_not_replied_since_baseline].freeze

    pattr_initialize [:account!, :conversation!, :conditions!, :message, :changed_attributes, :enrollment]

    def match?
      return true if conditions.blank?

      if kanban_trigger_context?
        return kanban_conditions_match? && non_kanban_conditions_match? && reply_conditions_match?
      end

      reply_conditions_match? && standard_match?
    rescue StandardError => e
      Rails.logger.error "Workflows::ConditionsEvaluator error: #{e.message}"
      false
    end

    private

    def kanban_trigger_context?
      changed_attributes.present? &&
        (changed_attributes.with_indifferent_access.key?(:pipeline_id) ||
         changed_attributes.with_indifferent_access.key?(:stage_id))
    end

    def kanban_conditions
      conditions.select { |c| KANBAN_ATTRIBUTE_KEYS.include?(c['attribute_key']) }
    end

    def non_kanban_conditions
      conditions.reject do |c|
        KANBAN_ATTRIBUTE_KEYS.include?(c['attribute_key']) || REPLY_ATTRIBUTE_KEYS.include?(c['attribute_key'])
      end
    end

    def kanban_conditions_match?
      return true if kanban_conditions.empty?

      kanban_conditions.all? { |condition| evaluate_kanban_condition(condition) }
    end

    def non_kanban_conditions_match?
      return true if non_kanban_conditions.empty?

      filter_match?(non_kanban_conditions)
    end

    def standard_match?
      standard_conditions = conditions.reject do |c|
        KANBAN_ATTRIBUTE_KEYS.include?(c['attribute_key']) || REPLY_ATTRIBUTE_KEYS.include?(c['attribute_key'])
      end
      return true if standard_conditions.empty?

      filter_match?(standard_conditions)
    end

    def reply_conditions_match?
      reply_conditions = conditions.select { |c| REPLY_ATTRIBUTE_KEYS.include?(c['attribute_key']) }
      return true if reply_conditions.empty?
      return false if enrollment.blank?

      reply_conditions.all? { |condition| evaluate_reply_condition(condition) }
    end

    def evaluate_reply_condition(condition)
      replied = enrollment.contact_replied_since_baseline?
      case condition['attribute_key']
      when 'contact_replied_since_baseline'
        replied
      when 'contact_not_replied_since_baseline'
        !replied
      else
        false
      end
    end

    def filter_match?(condition_set)
      rule = ConditionRuleAdapter.new(
        account: account,
        conditions: condition_set,
        id: 0
      )
      ::AutomationRules::ConditionsFilterService.new(
        rule,
        conversation,
        { message: message, changed_attributes: changed_attributes }.compact
      ).perform.present?
    end

    def evaluate_kanban_condition(condition)
      key = condition['attribute_key']
      operator = condition['filter_operator']
      expected = Array(condition['values']).map(&:to_s)

      actual = case key
               when 'kanban_pipeline_id'
                 extract_changed_value('pipeline_id').to_s
               when 'kanban_stage_id'
                 extract_changed_value('stage_id').to_s
               else
                 return false
               end

      case operator
      when 'equal_to'
        expected.include?(actual)
      when 'not_equal_to'
        expected.exclude?(actual)
      else
        false
      end
    end

    def extract_changed_value(attr)
      val = changed_attributes.with_indifferent_access[attr]
      val.is_a?(Array) ? val.last : val
    end
  end
end
