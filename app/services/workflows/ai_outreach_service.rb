# frozen_string_literal: true

module Workflows
  class AiOutreachService
    LAST_MESSAGES_LIMIT = 5

    pattr_initialize [:workflow!, :enrollment!, :conversation!, :node!]

    def perform!
      unless workflow.account.feature_enabled?('inteligencia_artificial')
        return record_result(success: false, error: 'feature_disabled')
      end

      inbox = conversation.inbox
      unless inbox.api?
        return record_result(success: false, error: 'inbox_not_supported')
      end

      webhook_url = inbox.channel.webhook_url
      if webhook_url.blank?
        return record_result(success: false, error: 'webhook_url_missing')
      end

      data = node['data'] || {}
      prompt = build_prompt(data)
      payload = conversation.webhook_data.merge(
        event: 'workflow.ai_outreach',
        prompt: prompt,
        ai_config: ai_config_payload(data),
        workflow_id: workflow.id,
        workflow_node_id: node['id'],
        enrollment_id: enrollment.id
      )

      payload[:context] = { last_messages: last_messages_payload }

      WebhookJob.perform_later(webhook_url, payload, :api_inbox_webhook)
      record_result(success: true)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: workflow.account).capture_exception
      record_result(success: false, error: 'send_failed', detail: e.message)
    end

    private

    def build_prompt(data)
      raw_prompt = data['prompt'].presence ||
                   Constants::AI_OUTREACH_OBJECTIVE_PROMPTS[data['objective_preset']] ||
                   Constants::AI_OUTREACH_OBJECTIVE_PROMPTS['reengagement']

      interpolated = MessageInterpolator.new(conversation).interpolate(raw_prompt)

      return interpolated if ActiveModel::Type::Boolean.new.cast(data['prompt_customized'])

      tone_key = data['tone_preset'].presence || 'friendly'
      tone_prefix = Constants::AI_OUTREACH_TONE_PREFIXES[tone_key] ||
                    Constants::AI_OUTREACH_TONE_PREFIXES['friendly']

      "#{tone_prefix} #{interpolated}".strip
    end

    def ai_config_payload(data)
      {
        objective_preset: data['objective_preset'].presence || 'reengagement',
        tone_preset: data['tone_preset'].presence || 'friendly',
        language: data['language'].presence || 'client',
        include_last_messages: true,
        prompt_customized: ActiveModel::Type::Boolean.new.cast(data['prompt_customized'])
      }
    end

    def last_messages_payload
      conversation.messages
                  .where(private: false)
                  .order(created_at: :desc)
                  .limit(LAST_MESSAGES_LIMIT)
                  .map do |message|
        {
          id: message.id,
          content: message.content,
          message_type: message.message_type,
          created_at: message.created_at
        }
      end.reverse
    end

    def record_result(success:, error: nil, detail: nil)
      execution = enrollment.workflow_step_executions.find_or_create_by!(node_id: node['id'])
      metadata = (execution.metadata || {}).merge(
        'ai_outreach' => {
          'success' => success,
          'error' => error,
          'detail' => detail
        }.compact
      )
      execution.update!(metadata: metadata)
      { success: success, error: error, detail: detail }.compact
    end
  end
end
