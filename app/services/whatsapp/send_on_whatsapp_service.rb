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
    should_send_template_message = template_params.present? || !message.conversation.can_reply?
    if should_send_template_message
      send_template_message
    else
      send_session_message
    end
  end

  def send_template_message
    name, namespace, lang_code, processed_parameters = resolve_template_delivery

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    message_id = channel.send_template(message, message.conversation.contact_inbox.source_id, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       })
    message.update!(source_id: message_id) if message_id.present?
  end

  def resolve_template_delivery
    return template_processor_call(interpolated_template_params) if template_params.present?

    matched_params = template_params_from_content_match
    return template_processor_call(matched_params) if matched_params.present?

    [nil, nil, nil, nil]
  end

  def template_processor_call(params)
    Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: params,
      message: message
    ).call
  end

  def template_params_from_content_match
    channel.message_templates&.each do |template|
      match_obj = template_match_object(template)
      next if match_obj.blank?

      return {
        'name' => template['name'],
        'namespace' => template['namespace'],
        'language' => template['language'],
        'processed_params' => match_obj.captures.each_with_index.with_object({}) do |(capture, index), params|
          params[(index + 1).to_s] = capture
        end
      }
    end

    nil
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

  def template_match_object(template)
    body_object = validated_body_object(template)
    return if body_object.blank?

    template_match_regex = build_template_match_regex(body_object['text'])
    message.content.match(template_match_regex)
  end

  def build_template_match_regex(template_text)
    template_text = template_text.gsub(/{{\d}}/, '(.*)')
    template_text = Regexp.escape(template_text)
    template_text = template_text.gsub(Regexp.escape('(.*)'), '(.*)')

    template_match_string = "^#{template_text}$"
    Regexp.new template_match_string
  end

  def validated_body_object(template)
    return if template['status'] != 'approved'

    template['components'].find { |obj| obj['type'] == 'BODY' && obj.key?('text') }
  end

  def send_session_message
    uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    phone_number = if uuid_regex.match?(message.conversation.contact_inbox.source_id)
                     message.conversation.contact_inbox.contact.phone_number.sub('+', '')
                   else
                     message.conversation.contact_inbox.source_id
                   end
    message_id = channel.send_message(phone_number, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end
end
