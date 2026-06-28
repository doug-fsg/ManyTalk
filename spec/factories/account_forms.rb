# frozen_string_literal: true

FactoryBot.define do
  factory :account_form do
    account
    sequence(:name) { |n| "Form #{n}" }
    sequence(:slug) { |n| "form-#{n}" }
    status { :draft }
    definition do
      {
        'fields' => [
          { 'key' => 'name', 'type' => 'native', 'field' => 'name', 'label' => 'Nome', 'required' => true },
          { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'label' => 'E-mail', 'required' => true },
          { 'key' => 'phone_number', 'type' => 'native', 'field' => 'phone_number', 'label' => 'Telefone', 'required' => false }
        ]
      }
    end
    branding do
      {
        'primary_color' => '#1f93ff',
        'logo_url' => '',
        'header_title' => '',
        'header_description' => ''
      }
    end
    settings do
      {
        'confirmation_message' => 'Obrigado!',
        'dedup_key' => 'email',
        'dedup_policy' => 'update_existing'
      }
    end

    trait :published do
      status { :published }
    end

    trait :paused do
      status { :paused }
    end
  end

  factory :form_submission do
    account_form
    account { account_form.account }
    contact
    payload do
      {
        'name' => 'Test User',
        'email' => 'test@example.com',
        'phone_number' => '+5511999999999'
      }
    end
    utm { {} }
  end
end
