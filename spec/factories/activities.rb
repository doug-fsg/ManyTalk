# frozen_string_literal: true

FactoryBot.define do
  factory :activity do
    account
    user { association :user, account: account }
    assignee { user }
    activity_type { 'task' }
    title { 'Follow up call' }
    description { 'Call the customer' }
    status { 'pending' }
    scheduled_at { 1.day.from_now }
    metadata { {} }

    trait :scheduled_message do
      activity_type { 'scheduled_message' }
      message_content { 'Hello from scheduled message' }
      inbox { association :inbox, account: account }
      contact { association :contact, account: account }
    end
  end
end
