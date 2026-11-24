# frozen_string_literal: true

# Resolves the WhatsApp Cloud `to` / recipient identifier for outbound sends.
# Aligns contact_inbox.source_id with contact.phone_number BR variants (9th digit)
# so template/session sends do not use a stale incomplete wa_id.
class Whatsapp::OutboundRecipient
  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  pattr_initialize [:contact_inbox!]

  def call
    source_id = contact_inbox.source_id.to_s
    return phone_digits_from_contact if uuid?(source_id)
    return source_id if source_id.blank?
    return source_id unless digits_only?(source_id)
    return source_id unless brazil_destination_resolution_applicable?(source_id)

    resolved = resolve_brazil_destination(source_id)
    log_normalization(source_id, resolved) if resolved != source_id
    resolved
  end

  private

  def contact
    @contact ||= contact_inbox.contact
  end

  def uuid?(value)
    UUID_REGEX.match?(value)
  end

  def digits_only?(value)
    value.match?(/\A\d+\z/)
  end

  def phone_digits_from_contact
    contact&.phone_number.to_s.delete('+').presence || contact_inbox.source_id.to_s
  end

  def resolve_brazil_destination(source_id)
    contact_digits = Contacts::BrazilPhoneNormalizer.digits(contact&.phone_number)
    return source_id if contact_digits.blank?

    source_variants = Contacts::BrazilPhoneNormalizer.lookup_variants(source_id)
    # Preserve E.164 "+" so international numbers are not treated as local BR (10/11 digits).
    contact_variants = Contacts::BrazilPhoneNormalizer.lookup_variants(contact&.phone_number)

    # No shared BR identity — keep Meta's stored source_id.
    overlap = source_variants & contact_variants
    return source_id if overlap.blank?

    # Prefer the form that matches the contact phone (often the full 13-digit mobile).
    preferred = preferred_brazil_form(contact_variants, source_variants)
    preferred.presence || source_id
  end

  # Prefer 13-digit BR mobile (with 9) when both forms are in the overlap set;
  # otherwise prefer contact's stored digits if it is a shared variant.
  def preferred_brazil_form(contact_variants, source_variants)
    overlap = contact_variants & source_variants
    return if overlap.blank?

    with_nine = overlap.find { |d| d.length == 13 && d.start_with?('55') }
    return with_nine if with_nine.present?

    contact_digits = Contacts::BrazilPhoneNormalizer.digits(contact&.phone_number)
    return contact_digits if overlap.include?(contact_digits)

    overlap.max_by(&:length)
  end

  # Only run ninth-digit / BR alignment when wa_id or contact phone is clearly Brazilian.
  def brazil_destination_resolution_applicable?(source_id)
    return true if brazil_international_form?(source_id)

    contact_number = contact&.phone_number.to_s.strip
    return false if contact_number.blank?

    contact_digits = Contacts::BrazilPhoneNormalizer.digits(contact_number)
    return true if brazil_international_form?(contact_digits)
    return true if local_brazil_pair?(source_id, contact_number, contact_digits)

    false
  end

  def brazil_international_form?(digits)
    digits.present? && digits.length.in?([12, 13]) && digits.start_with?('55')
  end

  def local_brazil_pair?(source_id, contact_raw, contact_digits)
    brazil_international_form?(source_id) &&
      !contact_raw.start_with?('+') &&
      contact_digits.length.in?([10, 11])
  end

  def log_normalization(original, resolved)
    Rails.logger.info(
      "[whatsapp_outbound_recipient] normalized to=#{resolved} from_source_id=#{original} " \
      "contact_inbox_id=#{contact_inbox.id} contact_id=#{contact_inbox.contact_id}"
    )
  end
end
