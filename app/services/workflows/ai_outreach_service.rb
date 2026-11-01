# frozen_string_literal: true

module Workflows
  class AiOutreachService
    LAST_MESSAGES_LIMIT = 5
    SYSTEM_PROMPT = <<~PROMPT.squish
      Você escreve uma única mensagem de outreach para o cliente no WhatsApp/chat.
      Responda somente com o texto da mensagem, sem JSON, sem markdown e sem aspas extras.
    PROMPT

    pattr_initialize [:workflow!, :enrollment!, :conversation!, :node!]

    def perform!
      unless workflow.account.feature_enabled?('inteligencia_artificial')
        return record_result(success: false, error: 'feature_disabled')
      end

      data = node['data'] || {}
      return perform_webhook!(data) unless native_attendant?

      completion = PlatformAiCompletion.complete(
        account: workflow.account,
        messages: chat_messages(data)
      )
      return record_quota_or_llm_error(completion) if completion[:error]

      text = completion[:content].to_s.strip
      return record_result(success: false, error: 'empty_response') if text.blank?

      send_outreach_message(text)
      record_result(success: true)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: workflow.account).capture_exception
      record_result(success: false, error: 'send_failed', detail: e.message)
    end

    private

    def native_attendant?
      workflow.account.feature_enabled?('atendimento_ia_nativo')
    end

    def perform_webhook!(data)
      webhook_url = AiWebhook.url
      return record_result(success: false, error: 'webhook_url_missing') if webhook_url.blank?

      WebhookJob.perform_later(webhook_url, build_payload(data))
      record_result(success: true)
    end

    def chat_messages(data)
      [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: build_payload(data).to_json }
      ]
    end

    def build_payload(data)
      prompt = build_prompt(data)
      conversation.webhook_data.merge(
        event: 'workflow.ai_outreach',
        prompt: prompt,
        ai_config: ai_config_payload(data),
        account_id: workflow.account_id,
        workflow_id: workflow.id,
        workflow_node_id: node['id'],
        enrollment_id: enrollment.id,
        inbox_id: selected_inbox_id(data),
        context: { last_messages: last_messages_payload }
      )
    end

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
        prompt_customized: ActiveModel::Type::Boolean.new.cast(data['prompt_customized']),
        inbox_id: selected_inbox_id(data)
      }.compact
    end

    def selected_inbox_id(data)
      id = data['inbox_id'].presence || conversation.inbox_id
      id.to_i
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

    def send_outreach_message(text)
      params = {
        content: text,
        private: false,
        content_attributes: {
          workflow_id: workflow.id,
          workflow_node_id: node['id']
        }
      }
      Messages::MessageBuilder.new(nil, conversation, params).perform
    end

    def record_quota_or_llm_error(completion)
      error = completion[:error] == :quota_exceeded ? 'quota_exceeded' : 'llm_error'
      record_result(success: false, error: error, detail: completion[:detail])
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
