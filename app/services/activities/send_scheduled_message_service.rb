class Activities::SendScheduledMessageService
  def initialize(activity)
    @activity = activity
  end

  def perform
    return unless @activity.scheduled_message?
    return unless @activity.pending?
    return unless @activity.inbox_id.present?
    return unless @activity.contact_id.present?

    conversation = find_or_create_conversation
    return unless conversation.present?

    user = @activity.user

    # Usar MessageBuilder existente
    mb = Messages::MessageBuilder.new(
      user,
      conversation,
      { content: @activity.message_content, private: false }
    )
    mb.perform

    # Marcar como concluída
    @activity.complete!

    Rails.logger.info "Mensagem agendada ##{@activity.id} enviada com sucesso"
  rescue StandardError => e
    Rails.logger.error "Erro ao enviar mensagem agendada ##{@activity.id}: #{e.message}"
    # Manter como pending para retry
  end

  private

  def find_or_create_conversation
    inbox = @activity.account.inboxes.find_by(id: @activity.inbox_id)
    return nil unless inbox

    contact = @activity.account.contacts.find_by(id: @activity.contact_id)
    return nil unless contact

    # Buscar contact_inbox ou criar
    contact_inbox = contact.contact_inboxes.find_or_create_by(inbox: inbox) do |ci|
      ci.source_id = SecureRandom.uuid
    end

    # Buscar última conversa aberta ou pendente
    conversation = contact_inbox.conversations
                                .where(status: [:open, :pending])
                                .order(created_at: :desc)
                                .first

    return conversation if conversation

    # Criar nova conversa se não existir
    ConversationBuilder.new(
      params: { status: 'open', assignee_id: @activity.assignee_id || @activity.user_id },
      contact_inbox: contact_inbox
    ).perform
  rescue StandardError => e
    Rails.logger.error "Erro ao buscar/criar conversa para atividade ##{@activity.id}: #{e.message}"
    nil
  end
end

