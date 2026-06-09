# frozen_string_literal: true

module Workflows
  module Constants
    ALLOWED_TRIGGER_EVENTS = %w[
      manual
      contact_kanban_stage_changed
      contact_kanban_stage_idle
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
      send_whatsapp_external
    ].freeze

    WAIT_RESPONDERS = %w[contact agent any].freeze

    NODE_TYPES = %w[trigger wait wait_for_reply condition action ai_outreach ai_conversation_analysis].freeze

    AI_ANALYSIS_TYPES = %w[
      executive_summary
      service_quality
      sales_opportunities
      customer_sentiment
      next_action
    ].freeze

    AI_ANALYSIS_OUTPUT_DESTINATIONS = %w[private_note whatsapp_external].freeze

    MAX_AI_ANALYSIS_MESSAGES = 100

    AI_OUTREACH_OBJECTIVES = %w[
      reengagement
      follow_up
      reminder
      appointment
      payment
    ].freeze

    AI_OUTREACH_TONES = %w[
      friendly
      professional
      sales
      support
    ].freeze

    AI_LANGUAGES = %w[
      client
      pt_BR
      pt_PT
      es
      en
    ].freeze

    MAX_AI_OUTREACH_PROMPT_LENGTH = 500

    AI_OUTREACH_OBJECTIVE_PROMPTS = {
      'reengagement' => 'Retome o contato com o cliente de forma amigável.',
      'follow_up' => 'Pergunte se o cliente ainda precisa de ajuda.',
      'reminder' => 'Lembre o cliente sobre o assunto em aberto.',
      'appointment' => 'Confirme o horário combinado com o cliente.',
      'payment' => 'Retome com o cliente sobre o pagamento pendente de forma educada.'
    }.freeze

    AI_OUTREACH_TONE_PREFIXES = {
      'friendly' => 'Tom amigável e próximo.',
      'professional' => 'Tom profissional e objetivo.',
      'sales' => 'Tom persuasivo, focado em conversão.',
      'support' => 'Tom empático, focado em resolver o problema.'
    }.freeze

    BRANCH_NODE_TYPES = %w[condition wait_for_reply].freeze

    CONDITION_SOURCE_HANDLES = %w[true false].freeze
    REPLY_WATCH_SOURCE_HANDLES = %w[replied timeout].freeze

    WAIT_UNITS = %w[minutes hours days].freeze

    WAIT_LIMITS = {
      'minutes' => { min: 1, max: 43_200 },
      'hours' => { min: 1, max: 720 },
      'days' => { min: 1, max: 90 }
    }.freeze

    MAX_GRAPH_BYTES = 512.kilobytes
    MAX_SEND_MESSAGE_ACTIONS = 15
    MAX_WAIT_NODES = 10
    MAX_WORKFLOWS_PER_EVENT = 100
    # After this many synchronous node advances, enqueue StepJob to avoid long-running jobs
    MAX_SYNC_ADVANCE_DEPTH = 5

    DEFAULT_SETTINGS = {
      'cancel_on_contact_reply' => false,
      'pause_on_contact_reply' => true,
      'cancel_on_conversation_resolved' => true,
      'allow_manual_start_only' => false,
      'enroll_latest_conversation_only' => true,
      'enrollment_scope' => 'contact',
      'respect_business_hours' => true
    }.freeze

    ENROLLMENT_SCOPES = %w[contact conversation].freeze
  end
end
