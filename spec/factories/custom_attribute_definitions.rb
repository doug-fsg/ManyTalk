# frozen_string_literal: true

FactoryBot.define do
  factory :custom_attribute_definition do
    sequence(:attribute_display_name) { |n| "Custom Attribute Definition #{n}" }
    sequence(:attribute_key) { |n| "custom_attribute_#{n}" }
    attribute_display_type { 1 }
    attribute_model { 0 }
    default_value { nil }
    is_kanban { false }
    account

    # Factory para atributos Kanban
    trait :kanban do
      attribute_display_type { 'list' }
      attribute_model { 'contact_attribute' }
      is_kanban { true }
      attribute_values { ['Estágio 1', 'Estágio 2', 'Estágio 3'] }
    end
  end
end
