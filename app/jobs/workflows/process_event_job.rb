# frozen_string_literal: true

module Workflows
  class ProcessEventJob < ApplicationJob
    queue_as :medium

    def perform(event_name, account_id, conversation_id = nil, message_id = nil, changed_attributes = nil)
      Workflows::OrchestratorService.on_event(
        event_name: event_name,
        account_id: account_id,
        conversation_id: conversation_id,
        message_id: message_id,
        changed_attributes: changed_attributes
      )
    end
  end
end
