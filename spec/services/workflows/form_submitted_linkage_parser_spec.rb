# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::FormSubmittedLinkageParser do
  describe '.extract_form_ids' do
    it 'returns form ids from equal_to account_form_id conditions' do
      conditions = [
        {
          'attribute_key' => 'account_form_id',
          'filter_operator' => 'equal_to',
          'values' => %w[5 7]
        }
      ]

      expect(described_class.extract_form_ids(conditions)).to eq(%w[5 7])
    end

    it 'ignores other attribute keys and operators' do
      conditions = [
        {
          'attribute_key' => 'form_slug',
          'filter_operator' => 'equal_to',
          'values' => ['my-form']
        },
        {
          'attribute_key' => 'account_form_id',
          'filter_operator' => 'not_equal_to',
          'values' => ['9']
        }
      ]

      expect(described_class.extract_form_ids(conditions)).to eq([])
    end
  end
end
