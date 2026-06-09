# frozen_string_literal: true

FactoryBot.define do
  factory :workflow do
    account
    sequence(:name) { |n| "Workflow #{n}" }
    description { 'Test workflow' }
    active { false }
    trigger_event_name { 'conversation_created' }
    graph do
      {
        'nodes' => [
          {
            'id' => 'trigger_1',
            'type' => 'trigger',
            'data' => { 'event_name' => 'conversation_created', 'conditions' => [] }
          },
          {
            'id' => 'action_1',
            'type' => 'action',
            'data' => { 'action_name' => 'add_label', 'action_params' => ['support'] }
          }
        ],
        'edges' => [
          { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'action_1' }
        ],
        'settings' => {
          'cancel_on_contact_reply' => true,
          'cancel_on_conversation_resolved' => true
        }
      }
    end
  end

  factory :workflow_enrollment do
    workflow
    conversation
    account { workflow.account }
    contact { conversation.contact }
    enrollment_scope { 'contact' }
    status { 'active' }
    current_node_id { 'trigger_1' }
    started_at { Time.current }
  end

  factory :workflow_step_execution do
    workflow_enrollment
    sequence(:node_id) { |n| "node_#{n}" }
    status { 'scheduled' }
    scheduled_at { 1.hour.from_now }
  end
end
