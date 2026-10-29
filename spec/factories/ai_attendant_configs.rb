# frozen_string_literal: true

FactoryBot.define do
  factory :ai_attendant_config do
    account
    sequence(:inbox_id) { |n| n }
    schedule_mode { 'always' }
  end
end
