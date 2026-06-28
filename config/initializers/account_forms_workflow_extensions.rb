# frozen_string_literal: true

# Extend workflow constants to support the form_submitted trigger event.
# This initializer appends form_submitted to the frozen constant safely.
Rails.application.config.after_initialize do
  Workflows::Constants.send(:remove_const, :ALLOWED_TRIGGER_EVENTS)
  Workflows::Constants.const_set(
    :ALLOWED_TRIGGER_EVENTS,
    %w[
      manual
      contact_kanban_stage_changed
      contact_kanban_stage_idle
      conversation_created
      conversation_updated
      conversation_opened
      conversation_resolved
      message_created
      form_submitted
    ].freeze
  )
end
