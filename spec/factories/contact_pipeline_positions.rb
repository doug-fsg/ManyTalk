# frozen_string_literal: true

FactoryBot.define do
  factory :contact_pipeline_position do
    contact
    pipeline { association :custom_attribute_definition, :kanban, account: contact.account }
    stage_id { 'Estágio 1' }
    position { 0 }
    entered_at { Time.current }
  end
end
