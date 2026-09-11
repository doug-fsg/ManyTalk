# frozen_string_literal: true

FactoryBot.define do
  factory :custom_role do
    account
    name { 'Supervisor' }
    description { 'Limited admin access' }
    permissions { ['report_manage'] }
  end
end
