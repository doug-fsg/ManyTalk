# frozen_string_literal: true

module Workflows
  class AiWaitForIntentService
    MAX_RECENT_MESSAGES = 3
    MAX_CONTENT_BYTES = 2.kilobytes
    SYSTEM_PROMPT = <<~PROMPT.squish
      Classifique se a mensagem do cliente corresponde à intenção descrita.
      Responda APENAS JSON: {"matched": true} ou {"matched": false}.
    PROMPT

    def initialize(enrollment, message)
      @enrollment = enrollment
      @message = message
    end

    def classify!
      unless @enrollment.account.feature_enabled?('inteligencia_artificial')
        log_metric('error', skip_reason: 'feature_disabled')
        return { matched: false }
      end

      intent_data = resolve_intent_data
      unless intent_data
        log_metric('error', skip_reason: 'unknown_intent_key')
        return { matched: false }
      end

      return classify_with_webhook!(intent_data) unless native_attendant?

      started_at = Time.current
      completion = PlatformAiCompletion.complete(
        account: @enrollment.account,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: build_payload(intent_data).to_json }
        ]
      )
      duration_ms = ((Time.current - started_at) * 1000).round

      if completion[:error] == :quota_exceeded
        log_metric('error', duration_ms: duration_ms, skip_reason: 'quota_exceeded')
        return { matched: false }
      end

      if completion[:error]
        log_metric('error', duration_ms: duration_ms, skip_reason: 'llm_error')
        return { ok: false, matched: false, error: completion[:error] }
      end

      matched = parse_matched(completion[:content])
      log_metric(matched ? 'matched' : 'not_matched', duration_ms: duration_ms)
      { ok: true, matched: matched }
    end

    private

    def native_attendant?
      @enrollment.account.feature_enabled?('atendimento_ia_nativo')
    end

    def classify_with_webhook!(intent_data)
      unless AiWebhook.configured?
        log_metric('error', skip_reason: 'no_webhook_url')
        return { matched: false }
      end

      started_at = Time.current
      result = SyncWebhookClient.post_json(
        AiWebhook.url,
        build_payload(intent_data),
        timeout: SyncWebhookClient::TIMEOUT
      )
      duration_ms = ((Time.current - started_at) * 1000).round

      outcome = result[:matched] ? 'matched' : 'not_matched'
      outcome = 'error' unless result[:ok]
      log_metric(outcome, duration_ms: duration_ms)
      result
    end

    def resolve_intent_data
      watch = @enrollment.intent_watch
      key = watch['intent_key']
      Constants::AI_INTENT_CATALOG.find { |i| i[:key] == key }
    end

    def build_payload(intent_data)
      watch = @enrollment.intent_watch
      custom_description = watch['intent_description'].presence
      description = custom_description || intent_data[:description]

      {
        event: 'workflow.ai_wait_for_intent',
        intent_key: intent_data[:key],
        intent: {
          key: intent_data[:key],
          label: intent_data[:label],
          description: description,
          catalog_description: intent_data[:description],
          custom_description: custom_description,
          examples: intent_data[:examples]
        }.compact,
        workflow_id: @enrollment.workflow_id,
        workflow_node_id: watch['node_id'],
        enrollment_id: @enrollment.id,
        deadline_at: watch['deadline_at'],
        message: message_payload,
        context: { recent_messages: recent_messages_payload }
      }
    end

    def message_payload
      return nil unless @message

      {
        id: @message.id,
        content: truncated_content(@message.content.to_s),
        message_type: @message.message_type,
        created_at: @message.created_at.iso8601
      }
    end

    def recent_messages_payload
      @enrollment.conversation.messages
                 .where.not(message_type: :activity)
                 .order(created_at: :desc)
                 .limit(MAX_RECENT_MESSAGES)
                 .map do |msg|
                   {
                     content: truncated_content(msg.content.to_s),
                     message_type: msg.message_type
                   }
                 end
    end

    def truncated_content(content)
      return content if content.bytesize <= MAX_CONTENT_BYTES

      content.byteslice(0, MAX_CONTENT_BYTES)
    end

    def parse_matched(content)
      json = content.to_s[/{.*}/m]
      return false if json.blank?

      data = JSON.parse(json)
      ActiveModel::Type::Boolean.new.cast(data['matched']) == true
    rescue JSON::ParserError
      false
    end

    def log_metric(result, duration_ms: nil, skip_reason: nil)
      Rails.logger.info(
        "[AiWaitForIntentService] enrollment=#{@enrollment.id} " \
        "result=#{result}" \
        "#{duration_ms ? " duration_ms=#{duration_ms}" : ''}" \
        "#{skip_reason ? " skip_reason=#{skip_reason}" : ''}"
      )
    end
  end
end
