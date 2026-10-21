class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Whatsapp
  end

  def invalid_message?
    super || skip_whatsapp_csat_send?
  end

  def skip_whatsapp_csat_send?
    return false unless channel.provider == 'whatsapp_cloud'

    message.input_csat?
  end

  def perform_reply
    if template_params.present?
      send_template_message
      return
    end

    return send_session_message if message.conversation.can_reply?

    message.update!(
      status: :failed,
      external_error: I18n.t('errors.whatsapp.message_outside_messaging_window')
    )
  end

  def send_template_message
    name, namespace, lang_code, processed_parameters = resolve_template_delivery

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    message_id = channel.send_template(message, outbound_recipient, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       })
    message.update!(source_id: message_id) if message_id.present?
  end

  def resolve_template_delivery
    return template_processor_call(interpolated_template_params) if template_params.present?

    [nil, nil, nil, nil]
  end

  def template_processor_call(params)
    Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: params,
      message: message
    ).call
  end

  def interpolated_template_params
    return template_params if template_params.blank?
    return template_params if template_params['processed_params'].blank?

    params = template_params.deep_dup
    interpolator = Messages::LiquidInterpolatorService.new(
      conversation: message.conversation,
      sender: message.sender
    )
    params['processed_params'] = interpolator.interpolate_value(params['processed_params'])
    params
  end

  def send_session_message
    message_id = channel.send_message(outbound_recipient, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def outbound_recipient
    Whatsapp::OutboundRecipient.new(contact_inbox: message.conversation.contact_inbox).call
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end
end
