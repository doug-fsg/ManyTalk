# frozen_string_literal: true

module Workflows
  class AiConversationAnalysisService
    pattr_initialize [:workflow!, :enrollment!, :conversation!, :node!]

    def perform!
      data = node['data'] || {}
      destination = data['output_destination'].presence || 'private_note'

      if destination == 'whatsapp_external'
        return deliver_whatsapp_analysis(data)
      end

      perform_webhook_analysis(data, destination)
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

      inbox = conversation.inbox
      unless inbox.api?
        return record_result(success: false, error: 'inbox_not_supported')
      end

      webhook_url = inbox.channel.webhook_url
      if webhook_url.blank?
        return record_result(success: false, error: 'webhook_url_missing')
      end

      payload = build_payload(data, destination)
      WebhookJob.perform_later(webhook_url, payload, :api_inbox_webhook)
      record_result(success: true)
    end

    def build_payload(data, destination)
      analysis_types = resolved_analysis_types(data)

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
