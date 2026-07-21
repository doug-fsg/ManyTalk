# frozen_string_literal: true

FactoryBot.define do
  factory :contact_pipeline_event do
    contact_pipeline_position
    account { contact_pipeline_position.contact.account }
    contact { contact_pipeline_position.contact }
    pipeline_id { contact_pipeline_position.pipeline_id }
    event_type { 'entered' }
    to_stage_id { contact_pipeline_position.stage_id }
    occurred_at { Time.current }
    metadata { {} }

    trait :stage_changed do
      event_type { 'stage_changed' }
      from_stage_id { 'Estágio 1' }
      to_stage_id { 'Estágio 2' }
    end

    trait :won do
      event_type { 'won' }
      metadata { { win_lost_notes: 'Closed deal' } }
    end
  end
end
