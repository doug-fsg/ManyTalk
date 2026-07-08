class Webhooks::WhatsappEventsJob < MutexApplicationJob
  queue_as :low
  retry_on ActiveRecord::RecordNotFound, wait: 30.seconds, attempts: 5
  retry_on LockAcquisitionError, wait: 2.seconds, attempts: 20

  def perform(params = {})
    channel = find_channel_from_whatsapp_business_payload(params)

    if channel_is_inactive?(channel)
      Rails.logger.warn("Inactive WhatsApp channel: #{channel&.phone_number || "unknown - #{params[:phone_number]}"}")
      return
    end

    sender_id = contact_sender_id(params)
    return process_events(channel, params) if sender_id.blank?

    key = format(Redis::RedisKeys::WHATSAPP_MESSAGE_MUTEX, inbox_id: channel.inbox.id, sender_id: sender_id)
    with_lock(key, 30.seconds) do
      process_events(channel, params)
    end
  end

  def process_events(channel, params)
    if message_echo_event?(params)
      handle_message_echo(channel, params)
    else
      handle_message_events(channel, params)
    end
  end

  def message_echo_event?(params)
    params.dig(:entry, 0, :changes, 0, :field) == 'smb_message_echoes'
  end

  def handle_message_echo(channel, params)
    Whatsapp::IncomingMessageEchoService.new(inbox: channel.inbox, params: params).perform
  end

  def handle_message_events(channel, params)
    case channel.provider
    when 'whatsapp_cloud'
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: channel.inbox, params: params).perform
    when 'unoapi'
      Whatsapp::IncomingMessageUnoapiService.new(inbox: channel.inbox, params: params).perform
    else
      Whatsapp::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    end
  end

  private

  def contact_sender_id(params)
    value = params.dig(:entry, 0, :changes, 0, :value) || params
    return contact_sender_id_from_message_echoes(value[:message_echoes]) if value[:message_echoes].present?

    contact_sender_id_from_messages(value[:messages], value[:contacts])
  end

  def contact_sender_id_from_message_echoes(message_echoes)
    message = message_echoes&.first
    return if message.blank?

    [message[:to_parent_user_id], message[:to_user_id], message[:to]].compact_blank.first
  end

  def contact_sender_id_from_messages(messages, contacts)
    message = messages&.first
    return if message.blank?

    contact = contacts&.first || {}

    [
      message[:from_parent_user_id],
      contact[:parent_user_id],
      message[:from_user_id],
      contact[:user_id],
      message[:from]
    ].compact_blank.first
  end

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?
    return true unless channel.account.active?

    false
  end

  def find_channel_by_url_param(params)
    return unless params[:phone_number]

    Channel::Whatsapp.find_by(phone_number: params[:phone_number])
  end

  def find_channel_from_whatsapp_business_payload(params)
    return get_channel_from_wb_payload(params) if params[:object] == 'whatsapp_business_account'

    find_channel_by_url_param(params)
  end

  def get_channel_from_wb_payload(wb_params)
    change = wb_params[:entry].first[:changes].first
    value = change.dig(:value, :metadata)

    if value.present?
      phone_number = "+#{value[:display_phone_number]}"
      phone_number_id = value[:phone_number_id]
      channel = Channel::Whatsapp.find_by(phone_number: phone_number)
      return channel if channel && channel.provider_config['phone_number_id'] == phone_number_id
    end

    find_channel_from_echo_payload(wb_params)
  end

  def find_channel_from_echo_payload(wb_params)
    echo = wb_params.dig(:entry, 0, :changes, 0, :value, :message_echoes, 0)
    return if echo.blank?

    business_number = echo[:from].to_s
    return if business_number.blank?

    phone_number = business_number.start_with?('+') ? business_number : "+#{business_number}"
    Channel::Whatsapp.find_by(phone_number: phone_number)
  end
end
