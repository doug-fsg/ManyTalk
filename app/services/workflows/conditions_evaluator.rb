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

      reply_conditions_match? && kanban_midflow_match? && standard_match?
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

    def kanban_midflow_match?
      return true if kanban_conditions.empty?
      return true if kanban_trigger_context?

      kanban_conditions.all? { |condition| evaluate_kanban_midflow_condition(condition) }
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
      replied = contact_replied_since_baseline?
      operator = condition['filter_operator']
      values = Array(condition['values'])

      if operator == 'is_present' || values.empty?
        case condition['attribute_key']
        when 'contact_replied_since_baseline'
          return replied
        when 'contact_not_replied_since_baseline'
          return !replied
        else
          return false
        end
      end

      expected = ActiveModel::Type::Boolean.new.cast(values.first)
      return false unless operator == 'equal_to'

      case condition['attribute_key']
      when 'contact_replied_since_baseline'
        replied == expected
      when 'contact_not_replied_since_baseline'
        !replied == expected
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
        {
          message: message,
          changed_attributes: changed_attributes,
          skip_validation: true
        }.compact
      ).perform.present?
    end

    def contact_replied_since_baseline?
      @contact_replied_since_baseline ||= enrollment.contact_replied_since_baseline?
    end

    def contact_pipeline_positions_by_pipeline
      @contact_pipeline_positions_by_pipeline ||= begin
        contact = conversation.contact
        if contact.blank?
          {}
        else
          contact.contact_pipeline_positions.index_by(&:pipeline_id)
        end
      end
    end

    def kanban_stage_for_pipeline(pipeline_id)
      contact_pipeline_positions_by_pipeline[pipeline_id.to_i]&.stage_id
    end

    def contact_in_pipeline?(pipeline_id)
      kanban_stage_for_pipeline(pipeline_id).present?
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

      compare_kanban_values(operator, expected, actual)
    end

    def evaluate_kanban_midflow_condition(condition)
      contact = conversation.contact
      return false if contact.blank?

      key = condition['attribute_key']
      operator = condition['filter_operator']
      expected = Array(condition['values']).map(&:to_s)

      case key
      when 'kanban_pipeline_id'
        in_expected = expected.any? { |pipeline_id| contact_in_pipeline?(pipeline_id) }
        case operator
        when 'equal_to', 'is_present'
          in_expected
        when 'not_equal_to', 'is_not_present'
          !in_expected
        else
          false
        end
      when 'kanban_stage_id'
        pipeline_id = pipeline_id_from_conditions
        return false if pipeline_id.blank?

        actual = kanban_stage_for_pipeline(pipeline_id).to_s
        compare_kanban_values(operator, expected, actual)
      else
        false
      end
    end

    def compare_kanban_values(operator, expected, actual)
      case operator
      when 'equal_to'
        expected.include?(actual)
      when 'not_equal_to'
        expected.exclude?(actual)
      else
        false
      end
    end

    def pipeline_id_from_conditions
      pipeline_cond = conditions.find { |c| c['attribute_key'] == 'kanban_pipeline_id' }
      return nil if pipeline_cond.blank?

      Array(pipeline_cond['values']).first
    end

    def extract_changed_value(attr)
      val = changed_attributes.with_indifferent_access[attr]
      val.is_a?(Array) ? val.last : val
    end
  end
end
