# frozen_string_literal: true

FactoryBot.define do
  factory :label_group do
    account
    sequence(:name) { |n| "Group #{n}" }
  end
end
