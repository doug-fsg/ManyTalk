# frozen_string_literal: true

module Workflows
  module Constants
    ALLOWED_TRIGGER_EVENTS = %w[
      conversation_created
      conversation_updated
      conversation_opened
      conversation_resolved
      message_created
    ].freeze

    ALLOWED_ACTION_NAMES = %w[
      send_message
      add_label
      remove_label
      send_email_to_team
      assign_team
      assign_agent
      send_webhook_event
      mute_conversation
      send_attachment
      change_status
      resolve_conversation
      snooze_conversation
      change_priority
      send_email_transcript
      change_kanban_stage
      add_private_note
    ].freeze

    NODE_TYPES = %w[trigger wait condition action].freeze

    WAIT_UNITS = %w[minutes hours days].freeze

    WAIT_LIMITS = {
      'minutes' => { min: 1, max: 43_200 },
      'hours' => { min: 1, max: 720 },
      'days' => { min: 1, max: 30 }
    }.freeze

    MAX_GRAPH_BYTES = 512.kilobytes
    MAX_SEND_MESSAGE_ACTIONS = 5
    MAX_WAIT_NODES = 3
    MAX_WORKFLOWS_PER_EVENT = 100
    # After this many synchronous node advances, enqueue StepJob to avoid long-running jobs
    MAX_SYNC_ADVANCE_DEPTH = 5

    DEFAULT_SETTINGS = {
      'cancel_on_contact_reply' => true,
      'cancel_on_conversation_resolved' => true
    }.freeze
  end
end
