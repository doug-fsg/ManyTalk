class Macros::ExecutionService < ActionService
  def initialize(macro, conversation, user)
    super(conversation)
    @macro = macro
    @account = macro.account
    @user = user
    Current.user = user
  end

  def perform
    @macro.actions.each do |action|
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "macro_event.#{@macro.name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def assign_agent(agent_ids)
    agent_ids = agent_ids.map { |id| id == 'self' ? @user.id : id }
    super(agent_ids)
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true }

    # Added reload here to ensure conversation us persistent with the latest updates
    mb = Messages::MessageBuilder.new(@user, @conversation.reload, params)
    mb.perform
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false }

    # Added reload here to ensure conversation us persistent with the latest updates
    mb = Messages::MessageBuilder.new(@user, @conversation.reload, params)
    mb.perform
  end

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @macro.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }

    # Added reload here to ensure conversation us persistent with the latest updates
    mb = Messages::MessageBuilder.new(@user, @conversation.reload, params)
    mb.perform
  end

  def change_kanban_stage(stage_params)
    pipeline_id = stage_params[0]
    selected_stage = stage_params[1]
    
    return unless pipeline_id.present? && selected_stage.present?
    
    contact = @conversation.contact
    return unless contact.present?
    
    kanban_attribute = @account.custom_attribute_definitions
      .find_by(id: pipeline_id, is_kanban: true)
    
    return unless kanban_attribute.present?
    
    # Verificar se o estágio selecionado existe no pipeline
    return unless kanban_attribute.attribute_values.include?(selected_stage)
    
    # Atualizar custom_attributes do contato
    old_attributes = contact.custom_attributes.dup
    new_attributes = contact.custom_attributes.merge({
      kanban_attribute.attribute_key => selected_stage
    })
    
    contact.update!(custom_attributes: new_attributes)
    
    # Criar mensagem de atividade
    create_kanban_activity_message(contact, kanban_attribute, selected_stage, old_attributes[kanban_attribute.attribute_key])
  rescue StandardError => e
    Rails.logger.error "[MACRO] Erro ao mover contato no kanban - contact_id: #{contact&.id}, pipeline_id: #{pipeline_id}, selected_stage: #{selected_stage}, error: #{e.message}"
  end

  private

  def create_kanban_activity_message(contact, kanban_attribute, new_stage, old_stage)
    return unless @conversation.present?
    
    user_name = Current.user&.name || 'Macro System'
    
    content = I18n.t(
      'conversations.activity.kanban.moved',
      user_name: user_name,
      stage_name: new_stage
    )
    
    message_params = {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :activity,
      content: content
    }
    
    ::Conversations::ActivityMessageJob.perform_later(@conversation, message_params)
  end
end
