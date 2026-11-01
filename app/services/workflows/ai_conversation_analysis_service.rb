# frozen_string_literal: true

module Workflows
  class AiConversationAnalysisService
    SYSTEM_PROMPT = <<~PROMPT.squish
      Analise a conversa. Responda APENAS um JSON objeto cujas chaves são os analysis_types
      pedidos e os valores são strings. Sem markdown.
    PROMPT

    TYPE_LABELS = ConversationAnalysisTextBuilder::TYPE_LABELS

    pattr_initialize [:workflow!, :enrollment!, :conversation!, :node!]

    def perform!
      data = node['data'] || {}
      destination = data['output_destination'].presence || 'private_note'

      if destination == 'whatsapp_external'
        return deliver_whatsapp_analysis(data)
      end

      if workflow.account.feature_enabled?('atendimento_ia_nativo')
        perform_platform_ai_analysis(data, destination)
      else
        perform_webhook_analysis(data, destination)
      end
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: workflow.account).capture_exception
      record_result(success: false, error: 'send_failed', detail: e.message)
    end

    private

    def deliver_whatsapp_analysis(data)
      unless workflow.account.feature_enabled?('inteligencia_artificial')
        return record_result(success: false, error: 'feature_disabled')
      end

      inbox_id = data['whatsapp_inbox_id']
      phone = data['whatsapp_phone']
      if inbox_id.blank? || phone.blank?
        return record_result(success: false, error: 'whatsapp_config_missing')
      end

      analysis_types = resolved_analysis_types(data)
      content = ConversationAnalysisTextBuilder.new(
        conversation: conversation,
        analysis_types: analysis_types,
        note_prefix: data['note_prefix']
      ).build

      result = ExternalWhatsappNotifier.new(
        account: workflow.account,
        inbox_id: inbox_id,
        phone_number: phone,
        message: content
      ).send!

      if result[:success]
        record_result(success: true, delivery: result[:delivery] || 'whatsapp')
      else
        record_result(success: false, error: result[:error], detail: result[:detail])
      end
    end

    def perform_webhook_analysis(data, destination)
      unless workflow.account.feature_enabled?('inteligencia_artificial')
        return record_result(success: false, error: 'feature_disabled')
      end

      webhook_url = AiWebhook.url
      return record_result(success: false, error: 'webhook_url_missing') if webhook_url.blank?

      analysis_types = resolved_analysis_types(data)
      WebhookJob.perform_later(webhook_url, build_payload(data, destination, analysis_types))
      record_result(success: true)
    end

    def perform_platform_ai_analysis(data, destination)
      unless workflow.account.feature_enabled?('inteligencia_artificial')
        return record_result(success: false, error: 'feature_disabled')
      end

      analysis_types = resolved_analysis_types(data)
      completion = PlatformAiCompletion.complete(
        account: workflow.account,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: build_payload(data, destination, analysis_types).to_json }
        ]
      )
      return record_quota_or_llm_error(completion) if completion[:error]

      parsed = parse_analysis_json(completion[:content])
      return record_result(success: false, error: 'invalid_json') if parsed.blank?

      persist_private_note(format_note(data, analysis_types, parsed))
      record_result(success: true)
    end

    def build_payload(data, destination, analysis_types)
      output = { destination: destination }
      output[:note_prefix] = data['note_prefix'].presence || 'Análise IA'

      conversation.webhook_data.merge(
        event: 'workflow.ai_conversation_analysis',
        analysis_types: analysis_types,
        output: output,
        ai_config: { locale: data['language'].presence || 'client' },
        workflow_id: workflow.id,
        workflow_node_id: node['id'],
        enrollment_id: enrollment.id,
        context: { messages: messages_payload }
      )
    end

    def resolved_analysis_types(data)
      types = (data['analysis_types'] || []).select { |t| Constants::AI_ANALYSIS_TYPES.include?(t) }
      types.presence || Constants::AI_ANALYSIS_TYPES
    end

    def messages_payload
      conversation.messages
                  .where(private: false)
                  .order(created_at: :asc)
                  .limit(Constants::MAX_AI_ANALYSIS_MESSAGES)
                  .map do |message|
        {
          id: message.id,
          content: message.content,
          message_type: message.message_type,
          created_at: message.created_at
        }
      end
    end

    def parse_analysis_json(content)
      json = content.to_s[/{.*}/m]
      return {} if json.blank?

      parsed = JSON.parse(json)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def format_note(data, analysis_types, parsed)
      prefix = data['note_prefix'].presence || 'Análise IA'
      lines = [prefix]
      analysis_types.each do |type|
        value = parsed[type].presence || parsed[type.to_sym]
        next if value.blank?

        label = TYPE_LABELS[type] || type.humanize
        lines << "#{label}: #{value}"
      end
      lines << parsed.values.map(&:to_s).join("\n") if lines.size == 1
      lines.join("\n")
    end

    def persist_private_note(content)
      params = {
        content: content,
        private: true,
        content_attributes: { workflow_id: workflow.id, workflow_node_id: node['id'] }
      }
      Messages::MessageBuilder.new(nil, conversation, params).perform
    end

    def record_quota_or_llm_error(completion)
      error = completion[:error] == :quota_exceeded ? 'quota_exceeded' : 'llm_error'
      record_result(success: false, error: error, detail: completion[:detail])
    end

    def record_result(success:, error: nil, detail: nil, delivery: nil)
      execution = enrollment.workflow_step_executions.find_or_create_by!(node_id: node['id'])
      metadata = (execution.metadata || {}).merge(
        'ai_conversation_analysis' => {
          'success' => success,
          'error' => error,
          'detail' => detail,
          'delivery' => delivery
        }.compact
      )
      execution.update!(metadata: metadata)
      { success: success, error: error, detail: detail, delivery: delivery }.compact
    end
  end
end
