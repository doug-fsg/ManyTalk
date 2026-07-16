# frozen_string_literal: true

class Activities::SendScheduledMessageService
  MAX_RETRIES = 3
  PERMANENT_FAILURE_REASONS = %w[
    outside_messaging_window
    template_not_found
    template_required
    conversation_not_found
    message_build_failed
  ].freeze

  def initialize(activity)
    @activity = activity
  end

  def perform
    return unless @activity.scheduled_message?
    return unless @activity.pending?
    return unless @activity.inbox_id.present?
    return unless @activity.contact_id.present?

    conversation = find_or_create_conversation
    return fail_activity('conversation_not_found') unless conversation

    dispatch_message(conversation)
  rescue StandardError => e
    Rails.logger.error "Erro ao enviar mensagem agendada ##{@activity.id}: #{e.message}"
    fail_activity('send_error', e)
  end

  private

  def dispatch_message(conversation)
    inbox = conversation.inbox
    if whatsapp_inbox?(inbox)
      dispatch_whatsapp_message(conversation)
    else
      dispatch_session_message(conversation)
    end
  end

  def dispatch_whatsapp_message(conversation)
    send_mode = whatsapp_send_mode
    template_params = whatsapp_template_params

    if conversation.can_reply? && send_mode != 'template_only'
      content = @activity.message_content.presence || template_preview_content(template_params)
      return fail_activity('message_content_required') if content.blank?

      send_via_message_builder(conversation, content: content)
    elsif template_params.present?
      content = template_preview_content(template_params) || @activity.message_content
      send_via_message_builder(conversation, content: content, template_params: template_params)
    elsif send_mode == 'session_only'
      fail_activity('outside_messaging_window')
    else
      fail_activity('template_required')
    end
  end

  def dispatch_session_message(conversation)
    content = @activity.message_content
    return fail_activity('message_content_required') if content.blank?

    send_via_message_builder(conversation, content: content)
  end

  def send_via_message_builder(conversation, content:, template_params: nil)
    params = { content: content, private: false }
    params[:template_params] = template_params if template_params.present?

    Messages::MessageBuilder.new(@activity.user, conversation, params).perform
    @activity.complete!
    Rails.logger.info "Mensagem agendada ##{@activity.id} enviada com sucesso"
  end

  def whatsapp_inbox?(inbox)
    inbox.channel_type == 'Channel::Whatsapp'
  end

  def whatsapp_send_mode
    @activity.metadata.dig('whatsapp', 'send_mode') ||
      @activity.metadata.dig(:whatsapp, :send_mode) ||
      'session_with_template_fallback'
  end

  def whatsapp_template_params
    params = @activity.metadata.dig('whatsapp', 'template_params') ||
             @activity.metadata.dig(:whatsapp, :template_params)
    params.presence
  end

  def template_preview_content(template_params)
    return if template_params.blank?

    processed = template_params['processed_params'] || template_params[:processed_params]
    return template_params['name'] || template_params[:name] if processed.blank?

    processed.values.join(' ').presence
  end

  def find_or_create_conversation
    inbox = @activity.account.inboxes.find_by(id: @activity.inbox_id)
    return nil unless inbox

    contact = @activity.account.contacts.find_by(id: @activity.contact_id)
    return nil unless contact

    contact_inbox = contact.contact_inboxes.find_or_create_by(inbox: inbox) do |ci|
      ci.source_id = SecureRandom.uuid
    end

    conversation = contact_inbox.conversations
                                .where(status: [:open, :pending])
                                .order(created_at: :desc)
                                .first

    return conversation if conversation

    ConversationBuilder.new(
      params: { status: 'open', assignee_id: @activity.assignee_id || @activity.user_id },
      contact_inbox: contact_inbox
    ).perform
  rescue StandardError => e
    Rails.logger.error "Erro ao buscar/criar conversa para atividade ##{@activity.id}: #{e.message}"
    nil
  end

  def fail_activity(reason, error = nil)
    retry_count = (@activity.metadata['retry_count'] || 0).to_i + 1
    metadata = @activity.metadata.to_h.merge(
      'retry_count' => retry_count,
      'failure_reason' => reason,
      'last_error' => error&.message,
      'failed_at' => Time.current.iso8601
    )

    if PERMANENT_FAILURE_REASONS.include?(reason) || retry_count >= MAX_RETRIES
      @activity.update!(status: 'failed', metadata: metadata)
      Rails.logger.error "Mensagem agendada ##{@activity.id} falhou permanentemente: #{reason}"
    else
      @activity.update!(metadata: metadata)
      Rails.logger.warn "Mensagem agendada ##{@activity.id} falhou (retry #{retry_count}/#{MAX_RETRIES}): #{reason}"
    end
  end
end
