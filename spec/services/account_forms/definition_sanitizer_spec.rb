# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForms::DefinitionSanitizer do
  it 'removes attribute_values from custom fields' do
    definition = {
      'fields' => [
        {
          'key' => 'cf_plan',
          'type' => 'custom_attribute',
          'attribute_key' => 'plan',
          'attribute_values' => [{ 'name' => 'A' }]
        }
      ]
    }

    sanitized = described_class.call(definition)
    field = sanitized['fields'].first

    expect(field).not_to have_key('attribute_values')
  end

  it 'preserves native fields unchanged' do
    definition = {
      'fields' => [
        { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'label' => 'E-mail' }
      ]
    }

    sanitized = described_class.call(definition)
    expect(sanitized['fields']).to eq(definition['fields'])
  end
end
