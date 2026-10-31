# frozen_string_literal: true

module Workflows
  # DEPRECATED: workflow AI nodes (outreach, analysis, wait-for-intent) now call
  # PlatformAi::ChatClient via Workflows::PlatformAiCompletion. Do not add new
  # callers. WORKFLOW_AI_URL remains only until dashboard/layout stop reading it.
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
