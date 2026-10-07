# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_schedule do
    account
    workflow { association :workflow, account: account, active: true }
    pipeline { association :custom_attribute_definition, :kanban, account: account }
    stage_id { 'Estágio 1' }
    sequence(:name) { |n| "Disparo recorrente #{n}" }
    weekday { 3 }
    hour { 9 }
    minute { 0 }
    time_zone { 'America/Sao_Paulo' }
    recurring { true }
    active { false }
    next_run_at { 1.day.from_now }
  end
end
