class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    @rule.actions.each do |action|
      @conversation.reload
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

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
    end
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
    
    # Obter stage anterior para mensagem de atividade
    old_position = ContactPipelinePosition.find_by(
      contact_id: contact.id,
      pipeline_id: pipeline_id
    )
    old_stage = old_position&.stage_id
    
    # Atualizar usando contact_pipeline_positions exclusivamente
    position = ContactPipelinePosition.update_stage(
      contact,
      pipeline_id,
      selected_stage,
      entered_at: Time.current
    )
    
    return unless position.present?
    
    # Criar mensagem de atividade
    create_kanban_activity_message(contact, kanban_attribute, selected_stage, old_stage)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
  end

  private

  def create_kanban_activity_message(contact, kanban_attribute, new_stage, old_stage)
    return unless @conversation.present?
    
    user_name = 'Automation System'
    
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
