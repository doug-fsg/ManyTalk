# This Builder will create a contact and contact inbox with specified attributes.
# If an existing identified contact exisits, it will be returned.
# for contact inbox logic it uses the contact inbox builder

class ContactInboxWithContactBuilder
  pattr_initialize [:inbox!, :contact_attributes!, :source_id, :hmac_verified]

  def perform
    find_or_create_contact_and_contact_inbox
  # in case of race conditions where contact is created by another thread
  # we will try to find the contact and create a contact inbox
  rescue ActiveRecord::RecordNotUnique
    find_or_create_contact_and_contact_inbox
  end

  def find_or_create_contact_and_contact_inbox
    @contact_inbox = find_existing_contact_inbox
    if @contact_inbox
      update_contact_avatar(@contact_inbox.contact) unless @contact_inbox.contact.avatar.attached?
      return @contact_inbox
    end

    ActiveRecord::Base.transaction(requires_new: true) do
      build_contact_with_contact_inbox
      update_contact_avatar(@contact) unless @contact.avatar.attached?
    end

    @contact_inbox
  end

  private

  def find_existing_contact_inbox
    resolved = effective_source_id
    return if resolved.blank?

    if whatsapp_inbox?
      candidates = Contacts::BrazilPhoneNormalizer.lookup_variants(resolved)
      inbox.contact_inboxes.where(source_id: candidates).first
    else
      inbox.contact_inboxes.find_by(source_id: resolved)
    end
  end

  def build_contact_with_contact_inbox
    @contact = find_contact || create_contact
    existing_ci = @contact.contact_inboxes.find_by(inbox_id: inbox.id)
    if existing_ci
      @contact_inbox = existing_ci
      return
    end

    @contact_inbox = create_contact_inbox
  end

  def account
    @account ||= inbox.account
  end

  def create_contact_inbox
    ContactInboxBuilder.new(
      contact: @contact,
      inbox: @inbox,
      source_id: effective_source_id,
      hmac_verified: hmac_verified
    ).perform
  end

  def effective_source_id
    return source_id if source_id.blank?
    return source_id unless whatsapp_inbox?

    Contacts::BrazilPhoneNormalizer.resolve_inbox_source_id(inbox: inbox, waid: source_id)
  end

  def whatsapp_inbox?
    inbox.channel_type == 'Channel::Whatsapp'
  end

  def update_contact_avatar(contact)
    ::Avatar::AvatarFromUrlJob.set(wait: 30.seconds).perform_later(contact, contact_attributes[:avatar_url]) if contact_attributes[:avatar_url]
  end

  def create_contact
    account.contacts.create!(
      name: contact_attributes[:name] || ::Haikunator.haikunate(1000),
      phone_number: contact_attributes[:phone_number],
      email: contact_attributes[:email],
      identifier: contact_attributes[:identifier],
      additional_attributes: contact_attributes[:additional_attributes],
      custom_attributes: contact_attributes[:custom_attributes]
    )
  end

  def find_contact
    contact = find_contact_by_identifier(contact_attributes[:identifier])
    contact ||= find_contact_by_email(contact_attributes[:email])
    contact ||= find_contact_by_phone_number(contact_attributes[:phone_number])
    contact
  end

  def find_contact_by_identifier(identifier)
    return if identifier.blank?

    account.contacts.find_by(identifier: identifier)
  end

  def find_contact_by_email(email)
    return if email.blank?

    account.contacts.from_email(email)
  end

  def find_contact_by_phone_number(phone_number)
    return if phone_number.blank?

    contact = account.contacts.find_by(phone_number: phone_number)
    return contact if contact

    candidates = Contacts::BrazilPhoneNormalizer.e164_lookup_variants(phone_number)
    return if candidates.blank?

    account.contacts.where(phone_number: candidates).first
  end
end
