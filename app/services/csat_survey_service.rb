class CsatSurveyService
  pattr_initialize [:conversation!]

  def perform
    return unless should_send_csat_survey?

    if whatsapp_cloud_channel? && template_available_and_approved?
      send_whatsapp_template_survey
    elsif whatsapp_cloud_channel?
      log_skipped_whatsapp_csat
    elsif within_messaging_window?
      ::MessageTemplates::Template::CsatSurvey.new(conversation: conversation).perform
    else
      create_csat_not_sent_activity_message
    end
  end

  private

  delegate :inbox, :contact, to: :conversation
  delegate :channel, to: :inbox

  def should_send_csat_survey?
    conversation_allows_csat? && csat_enabled? && !csat_already_sent? && csat_allowed_by_survey_rules?
  end

  def conversation_allows_csat?
    conversation.resolved? && !conversation.tweet?
  end

  def csat_enabled?
    inbox.csat_survey_enabled?
  end

  def csat_already_sent?
    conversation.messages.where(content_type: :input_csat).present?
  end

  def within_messaging_window?
    conversation.can_reply?
  end

  def whatsapp_cloud_channel?
    inbox.channel_type == 'Channel::Whatsapp' && channel.provider == 'whatsapp_cloud'
  end

  def csat_allowed_by_survey_rules?
    return true unless survey_rules_configured?

    labels = conversation.label_list
    return true if rule_values.empty?

    case rule_operator
    when 'contains'
      rule_values.any? { |label| labels.include?(label) }
    when 'does_not_contain'
      rule_values.none? { |label| labels.include?(label) }
    else
      true
    end
  end

  def survey_rules_configured?
    return false if csat_config.blank?
    return false if csat_config['survey_rules'].blank?

    rule_values.any?
  end

  def rule_operator
    csat_config.dig('survey_rules', 'operator') || 'contains'
  end

  def rule_values
    csat_config.dig('survey_rules', 'values') || []
  end

  def csat_config
    inbox.csat_config || {}
  end

  def template_available_and_approved?
    template_config = csat_config['template']
    return false unless template_config

    template_name = template_config['name'] || CsatTemplateNameService.csat_template_name(inbox.id)
    status_result = channel.provider_service.get_template_status(template_name)

    status_result[:success] && status_result[:template][:status] == 'APPROVED'
  rescue StandardError => e
    Rails.logger.error "[CSAT] Error checking template status for conversation #{conversation.id}: #{e.message}"
    false
  end

  def send_whatsapp_template_survey
    template_config = csat_config['template']
    template_name = template_config['name'] || CsatTemplateNameService.csat_template_name(inbox.id)
    phone_number = conversation.contact_inbox.source_id
    template_info = build_template_info(template_name, template_config)

    message = build_csat_message
    message.save!

    message_id = channel.send_template(message, phone_number, template_info)
    message.update!(source_id: message_id) if message_id.present?
  rescue StandardError => e
    Rails.logger.error "[CSAT] Error sending WhatsApp CSAT for conversation #{conversation.id}: #{e.message}"
  end

  def build_template_info(template_name, template_config)
    {
      name: template_name,
      lang_code: template_config['language'] || 'en',
      parameters: [
        {
          type: 'button',
          sub_type: 'url',
          index: '0',
          parameters: [{ type: 'text', text: conversation.uuid }]
        }
      ]
    }
  end

  def build_csat_message
    conversation.messages.build(
      account: conversation.account,
      inbox: inbox,
      message_type: :outgoing,
      content: csat_config['message'].presence || I18n.t('conversations.templates.csat_input_message_body'),
      content_type: :input_csat,
      content_attributes: { whatsapp_csat: true }
    )
  end

  def log_skipped_whatsapp_csat
    Rails.logger.info(
      "[CSAT] Skipping WhatsApp CSAT for conversation #{conversation.id}: " \
      'template missing or not approved yet'
    )
  end

  def create_csat_not_sent_activity_message
    content = I18n.t('conversations.activity.csat.not_sent_due_to_messaging_window')
    activity_message_params = {
      account_id: conversation.account_id,
      inbox_id: inbox.id,
      message_type: :activity,
      content: content
    }
    ::Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params)
  end
end
