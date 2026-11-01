# frozen_string_literal: true

module Workflows
  # Outbound URL for workflow AI nodes while atendimento_ia_nativo is off.
  # Accounts with that flag use PlatformAi::ChatClient instead.
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
