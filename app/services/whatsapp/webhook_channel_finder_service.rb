# frozen_string_literal: true

# Resolves the WhatsApp channel for an inbound WhatsApp Cloud webhook.
# Meta's display_phone_number can arrive formatted or as a BR variant (with/without
# the mobile 9th digit), so we try the raw digits first and then BR variants,
# accepting only a candidate whose phone_number_id matches.
class Whatsapp::WebhookChannelFinderService
  def initialize(display_phone_number:, phone_number_id:)
    @display_phone_number = display_phone_number
    @phone_number_id = phone_number_id
  end

  def perform
    return if digits.blank? || @phone_number_id.blank?

    candidates = phone_candidates.filter_map do |number|
      Channel::Whatsapp.find_by(phone_number: "+#{number}")
    end

    candidates.find { |channel| channel.provider_config['phone_number_id'].to_s == @phone_number_id.to_s }
  end

  private

  def digits
    @digits ||= @display_phone_number.to_s.gsub(/[^0-9]/, '')
  end

  def phone_candidates
    variants = Contacts::BrazilPhoneNormalizer.lookup_variants(digits)
    ([digits] + variants).compact_blank.uniq
  end
end
