class Whatsapp::Providers::WhatsappCloudService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(message, phone_number, template_info)
    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        to: phone_number,
        template: template_body_parameters(template_info),
        type: 'template'
      }.to_json
    )

    process_response(message, response)
  end

  def sync_templates
    templates = fetch_whatsapp_templates
    whatsapp_channel.update_columns(
      message_templates: templates,
      message_templates_last_updated: Time.now.utc
    )
  end

  def fetch_whatsapp_templates(url = nil)
    url ||= "#{business_account_path}/message_templates"
    headers = url.include?('access_token=') ? {} : api_headers
    response = HTTParty.get(url, headers: headers)

    unless response.success?
      Rails.logger.error "[WHATSAPP] Template sync failed for channel #{whatsapp_channel.id}: #{response.code} - #{response.body}"
      record_authorization_error_from_meta!(response)
      raise StandardError, template_sync_error_message(response)
    end

    data = response['data'] || []
    next_page = next_url(response)

    return data + fetch_whatsapp_templates(next_page) if next_page.present?

    data
  end

  def next_url(response)
    response['paging'] ? response['paging']['next'] : ''
  end

  def validate_provider_config?
    response = HTTParty.get("#{business_account_path}/message_templates", headers: api_headers)
    response.success?
  end

  def get_template_status(template_name)
    Whatsapp::CsatTemplateService.new(whatsapp_channel).get_template_status(template_name)
  end

  def api_headers
    { 'Authorization' => "Bearer #{whatsapp_channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
  end

  def media_url(media_id)
    "#{api_base_path}/v13.0/#{media_id}"
  end

  def message_update_payload(message)
    payload = {
      messaging_product: 'whatsapp',
      status: message[:status],
      message_id: message[:source_id],
      recipient_id: message[:sender][:phone_number]
    }
    if message[:conversation][:contact_inbox][:source_id].include?('@g.us')
      payload.merge({ group_id: message[:conversation][:contact_inbox][:source_id] })
    end
    payload
  end

  def message_update_http_method
    :post
  end

  def message_path(_message)
    messages_path
  end

  private

  def api_base_path
    whatsapp_channel.provider_config['url'] || ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end

  # TODO: See if we can unify the API versions and for both paths and make it consistent with out facebook app API versions
  def phone_id_path
    "#{api_base_path}/v13.0/#{whatsapp_channel.provider_config['phone_number_id']}"
  end

  def messages_path
    "#{phone_id_path}/messages"
  end

  def business_account_path
    "#{api_base_path}/#{api_version}/#{whatsapp_channel.provider_config['business_account_id']}"
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end

  def template_sync_error_message(response)
    meta_error(response)&.dig('message') || 'Failed to sync WhatsApp templates'
  end

  # Meta auth/permission failures → existing Reauthorizable flow (banner after threshold).
  # 190 = invalid/expired token; 100/33 = object inaccessible / missing permissions.
  def record_authorization_error_from_meta!(response)
    return unless meta_authorization_error?(response)

    whatsapp_channel.authorization_error!
  end

  def meta_authorization_error?(response)
    return true if response.code.to_i == 401

    error = meta_error(response)
    return false unless error

    code = error['code'].to_i
    subcode = error['error_subcode'].to_i
    code == 190 || (code == 100 && subcode == 33)
  end

  def meta_error(response)
    parsed = response.parsed_response
    parsed.is_a?(Hash) ? parsed['error'] : nil
  end

  def send_text_message(phone_number, message)
    response = HTTParty.post(
      messages_path,
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        context: whatsapp_reply_context(message),
        to: phone_number,
        text: { body: format_content(message) },
        type: 'text'
      }.to_json
    )

    process_response(message, response)
  end

  def format_content(message)
    feature = whatsapp_channel.inbox.account.feature_enabled?('send_agent_name_in_whatsapp_message')
    config = whatsapp_channel.provider_config['send_agent_name']
    return message.content if !feature && !config

    message&.sender_name.present? ? "*#{message&.sender_name}*: \n#{message.content}" : message.content
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    voice = voice_note_eligible?(attachment)
    normalize_whatsapp_ogg_mime!(attachment) if voice

    type_content = attachment_type_content(attachment, message, type, voice: voice)
    response = post_attachment_message(phone_number, message, type, type_content)

    # Same OGG without voice = basic audio (no waveform). One retry only.
    if !response.success? && voice
      Rails.logger.info(
        "[whatsapp_voice_notes] fallback without voice message_id=#{message.id} " \
        "account_id=#{message.account_id}"
      )
      type_content = attachment_type_content(attachment, message, type, voice: false)
      response = post_attachment_message(phone_number, message, type, type_content)
    end

    process_response(message, response)
  end

  def attachment_type_content(attachment, message, type, voice:)
    type_content = { link: attachment.download_url }
    type_content[:caption] = message.content unless %w[audio sticker].include?(type)
    type_content[:filename] = attachment.file.filename if type == 'document'
    type_content[:voice] = true if voice
    type_content
  end

  def post_attachment_message(phone_number, message, type, type_content)
    HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        context: whatsapp_reply_context(message),
        to: phone_number,
        type: type,
        type.to_s => type_content
      }.to_json
    )
  end

  def voice_note_eligible?(attachment)
    return false unless whatsapp_channel.inbox.account.feature_enabled?('whatsapp_voice_notes')
    return false unless attachment&.audio?
    return false unless attachment.file.attached?

    content_type = attachment.file.content_type.to_s
    content_type.include?('ogg') || content_type == 'audio/opus' ||
      attachment.file.filename.to_s.downcase.end_with?('.ogg')
  end

  def normalize_whatsapp_ogg_mime!(attachment)
    blob = attachment.file.blob
    return unless blob.content_type == 'audio/opus'

    blob.update_column(:content_type, 'audio/ogg') # rubocop:disable Rails/SkipsModelValidations
  end

  def process_response(message, response)
    if response.success?
      response['messages'].first['id']
    else
      Rails.logger.error response.body
      external_error = humanize_whatsapp_error(response)
      message.update!(status: :failed, external_error: external_error)
      nil
    end
  end

  def humanize_whatsapp_error(response)
    parsed = response.parsed_response
    error = parsed.is_a?(Hash) ? parsed['error'] : nil
    return response.body if error.blank?

    Whatsapp::ErrorHumanizer.humanize(
      code: error['code'],
      details: error.dig('error_data', 'details') || error['message']
    )
  end

  def template_body_parameters(template_info)
    components = normalize_template_components(template_info[:parameters])

    {
      name: template_info[:name],
      language: {
        policy: 'deterministic',
        code: template_info[:lang_code]
      },
      components: components
    }
  end

  def normalize_template_components(parameters)
    return [{ type: 'body', parameters: [] }] if parameters.blank?
    return parameters if parameters.first.is_a?(Hash) && parameters.first[:type] != 'text'

    [{ type: 'body', parameters: parameters }]
  end

  def whatsapp_reply_context(message)
    reply_to = message.content_attributes[:in_reply_to_external_id]
    return nil if reply_to.blank?

    {
      message_id: reply_to
    }
  end

  def send_interactive_text_message(phone_number, message)
    payload = create_payload_based_on_items(message)

    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        to: phone_number,
        interactive: payload,
        type: 'interactive'
      }.to_json
    )

    process_response(message, response)
  end
end
