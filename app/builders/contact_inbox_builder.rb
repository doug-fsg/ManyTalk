# This Builder will create a contact inbox with specified attributes. If the contact inbox already exists, it will be returned.
# For Specific Channels like whatsapp, email etc . it smartly generated appropriate the source id when none is provided.

class ContactInboxBuilder
  pattr_initialize [:contact, :inbox, :source_id, { hmac_verified: false }]

  def perform
    @source_id = resolved_source_id
    @source_id ||= generate_source_id
    create_contact_inbox if source_id.present?
  end

  private

  def resolved_source_id
    return @source_id unless whatsapp_channel?

    digits = (@source_id.presence || @contact.phone_number&.delete('+')).to_s
    return if digits.blank?

    existing_ci = @contact.contact_inboxes.find_by(inbox: @inbox)
    return existing_ci.source_id if existing_ci

    candidates = Contacts::BrazilPhoneNormalizer.lookup_variants(digits)
    existing_ci = @inbox.contact_inboxes.where(contact: @contact, source_id: candidates).first
    return existing_ci.source_id if existing_ci

    Contacts::BrazilPhoneNormalizer.resolve_inbox_source_id(inbox: @inbox, waid: digits)
  end

  def whatsapp_channel?
    @inbox.channel_type == 'Channel::Whatsapp'
  end

  def generate_source_id
    case @inbox.channel_type
    when 'Channel::TwilioSms'
      twilio_source_id
    when 'Channel::Whatsapp'
      wa_source_id
    when 'Channel::Email'
      email_source_id
    when 'Channel::Sms'
      phone_source_id
    when 'Channel::Api', 'Channel::WebWidget'
      SecureRandom.uuid
    when 'Channel::NotificaMe'
      notifica_me_source_id
    else
      raise "Unsupported operation for this channel: #{@inbox.channel_type}"
    end
  end

  def notifica_me_source_id
    return @contact.phone_number if %w[telegram whatsapp sms].include?(@inbox.channel.notifica_me_type)
    raise ActionController::ParameterMissing, 'contact email' unless @contact.source_id

    @contact.source_id
  end

  def email_source_id
    raise ActionController::ParameterMissing, 'contact email' unless @contact.email

    @contact.email
  end

  def phone_source_id
    raise ActionController::ParameterMissing, 'contact phone number' unless @contact.phone_number

    @contact.phone_number
  end

  def wa_source_id
    raise ActionController::ParameterMissing, 'contact phone number' unless @contact.phone_number

    # whatsapp doesn't want the + in e164 format
    @contact.phone_number.delete('+').to_s
  end

  def twilio_source_id
    raise ActionController::ParameterMissing, 'contact phone number' unless @contact.phone_number

    case @inbox.channel.medium
    when 'sms'
      @contact.phone_number
    when 'whatsapp'
      "whatsapp:#{@contact.phone_number}"
    end
  end

  def create_contact_inbox
    existing = find_existing_contact_inbox
    return existing if existing

    ::ContactInbox.create_with(hmac_verified: hmac_verified || false).find_or_create_by!(
      contact_id: @contact.id,
      inbox_id: @inbox.id,
      source_id: @source_id
    )
  end

  def find_existing_contact_inbox
    return unless whatsapp_channel?

    candidates = Contacts::BrazilPhoneNormalizer.lookup_variants(@source_id)
    @inbox.contact_inboxes.where(contact_id: @contact.id, source_id: candidates).first ||
      @contact.contact_inboxes.find_by(inbox: @inbox)
  end
end
