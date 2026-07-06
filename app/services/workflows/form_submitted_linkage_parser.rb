# frozen_string_literal: true

module Workflows
  module FormSubmittedLinkageParser
    module_function

    def extract_form_ids(conditions)
      Array(conditions).flat_map do |condition|
        next [] unless condition['attribute_key'].to_s == 'account_form_id'
        next [] unless condition['filter_operator'].to_s == 'equal_to'

        Array(condition['values']).map(&:to_s)
      end.uniq
    end
  end
end
