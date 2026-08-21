# frozen_string_literal: true

module Workflows
  # Single outbound URL for all workflow AI nodes.
  # Distinguish behavior on the receiver by payload `event`:
  #   workflow.ai_outreach | workflow.ai_conversation_analysis | workflow.ai_wait_for_intent
  module AiWebhook
    ENV_KEY = 'WORKFLOW_AI_URL'

    module_function

    def url
      ENV[ENV_KEY].presence
    end

    def configured?
      url.present?
    end
  end
end
