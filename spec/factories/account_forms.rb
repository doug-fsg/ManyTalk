# frozen_string_literal: true

FactoryBot.define do
  factory :account_form do
    account
    sequence(:name) { |n| "Form #{n}" }
    sequence(:slug) { |n| "form-#{n}" }
    status { :draft }
    definition { AccountForm::DEFAULT_DEFINITION.deep_dup }
    branding { AccountForm::DEFAULT_BRANDING.deep_dup }
    settings { AccountForm::DEFAULT_SETTINGS.deep_dup }

    trait :published do
      status { :published }
    end

    trait :paused do
      status { :paused }
    end
  end
end
