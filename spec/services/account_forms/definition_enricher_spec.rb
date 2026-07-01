# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForms::DefinitionEnricher do
  let(:account) { create(:account) }
  let!(:list_attribute) do
    create(
      :custom_attribute_definition,
      account: account,
      attribute_model: :contact_attribute,
      attribute_key: 'plan_type',
      attribute_display_type: 'list',
      attribute_values: [
        { name: 'Básico', color: '#111111' },
        { name: 'Premium', color: '#222222' }
      ]
    )
  end

  let(:form) do
    create(
      :account_form,
      account: account,
      definition: {
        'fields' => [
          {
            'key' => 'cf_plan_type',
            'type' => 'custom_attribute',
            'attribute_key' => 'plan_type',
            'label' => 'Plano',
            'required' => false,
            'attribute_values' => [{}]
          }
        ]
      }
    )
  end

  it 'loads list options from the attribute definition when saved values are empty' do
    definition = described_class.call(form)
    field = definition['fields'].first

    expect(field['attribute_display_type']).to eq('list')
    expect(field['attribute_values']).to eq(['Básico', 'Premium'])
  end

  it 'loads options from string array attributes' do
    list_attribute.update!(attribute_values: %w[Opção A Opção B])
    definition = described_class.call(form)
    field = definition['fields'].first

    expect(field['attribute_values']).to eq(['Opção A', 'Opção B'])
  end

  it 'loads options from nested stages hash' do
    list_attribute.update!(
      attribute_values: {
        'stages' => {
          'Estágio 1' => { 'color' => '#aaa' },
          'Estágio 2' => { 'color' => '#bbb' }
        }
      }
    )

    definition = described_class.call(form)
    field = definition['fields'].first

    expect(field['attribute_values']).to eq(['Estágio 1', 'Estágio 2'])
  end
end
