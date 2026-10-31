# frozen_string_literal: true

FactoryBot.define do
  factory :ai_attendant_config do
    account
    schedule_mode { 'always' }
    avatar_id { 'avatar_1' }

    transient do
      inbox_id { nil }
      inbox { nil }
      inbox_ids { nil }
    end

    after(:create) do |config, evaluator|
      ids =
        if evaluator.inbox_ids.present?
          Array(evaluator.inbox_ids)
        elsif evaluator.inbox.present?
          [evaluator.inbox.id]
        elsif evaluator.inbox_id.present?
          [evaluator.inbox_id]
        else
          [create(:inbox, account: config.account).id]
        end

      ids.each do |inbox_id|
        create(:ai_attendant_config_inbox, ai_attendant_config: config, inbox_id: inbox_id)
      end
    end
  end

  factory :ai_attendant_config_inbox do
    ai_attendant_config
    inbox_id { create(:inbox, account: ai_attendant_config.account).id }
  end
end
