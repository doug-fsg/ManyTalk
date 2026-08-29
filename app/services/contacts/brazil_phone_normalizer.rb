# frozen_string_literal: true

module Contacts
  # Lookup helpers for Brazilian mobile numbers that may arrive with or without
  # the extra 9 after the DDD (WhatsApp issue #5840).
  #
  # International form: 55 (country) + DDD(2) + subscriber (8 or 9 digits).
  # DDD 55 is a valid area code (RS) — do not confuse with country code 55.
  #
  # Variants are for matching only. Do not rewrite Meta's wa_id when creating
  # a new contact_inbox.
  class BrazilPhoneNormalizer
    class << self
      def digits(raw)
        raw.to_s.gsub(/\D/, '').presence
      end

      # Digit candidates for WHERE IN on contact_inbox.source_id / wa_id.
      # Local 10/11 digits (without leading +) get country 55 prepended for
      # variant generation. E.164 inputs (+...) are treated as already
      # international — never invent a BR country code for them.
      def lookup_variants(raw)
        original = digits(raw)
        return [] if original.blank?

        if international_mobile?(original)
          return ninth_digit_variants(original)
        end

        if local_brazilian_entry?(raw, original)
          international = "55#{original}"
          return ([original] + ninth_digit_variants(international)).uniq
        end

        [original]
      end

      def e164_lookup_variants(raw)
        lookup_variants(raw).map { |d| "+#{d}" }.uniq
      end

      # Canonical E.164 for create/store. Does not add or strip the Brazilian 9.
      def to_e164(raw)
        original = digits(raw)
        return if original.blank?

        if local_brazilian_entry?(raw, original)
          "+55#{original}"
        else
          "+#{original}"
        end
      end

      def canonical_lookup_key(raw)
        lookup_variants(raw).min
      end

      # Alias used by WhatsApp helpers.
      def source_id_candidates(raw)
        lookup_variants(raw)
      end

      # Prefer existing contact_inbox.source_id (with or without 9).
      # If none matches, return the original waid — never force with-9 on create.
      def resolve_inbox_source_id(inbox:, waid:)
        original = digits(waid) || waid.to_s
        return original if original.blank?
        return original unless brazil_phone_number?(original)

        lookup_variants(original).each do |candidate|
          contact_inbox = inbox.contact_inboxes.find_by(source_id: candidate)
          return contact_inbox.source_id if contact_inbox.present?
        end

        original
      end

      # Backwards-compatible name for WhatsApp helpers / plan snippets.
      alias resolved_source_id_for_inbox resolve_inbox_source_id

      def find_contact(account:, phone_number:, inbox: nil)
        return if phone_number.blank?

        candidates = ([phone_number] + e164_lookup_variants(phone_number)).uniq
        matching = account.contacts.where(phone_number: candidates)
        return matching.first if inbox.blank?

        open_id = matching.joins(:conversations)
                          .where(conversations: { inbox_id: inbox.id, status: :open })
                          .order('conversations.updated_at DESC')
                          .limit(1)
                          .pluck('contacts.id')
                          .first
        matching.find_by(id: open_id) || matching.first
      end

      private

      def ninth_digit_variants(international)
        [
          international,
          with_ninth_digit(international),
          without_ninth_digit(international)
        ].compact.uniq
      end

      # Spreadsheet/CRM style local entry: digits only, no explicit country (+).
      def local_brazilian_entry?(raw, digit_string)
        !raw.to_s.strip.start_with?('+') && digit_string.length.in?([10, 11])
      end

      def brazil_phone_number?(digit_string)
        digit_string.match?(/\A55/)
      end

      def international_mobile?(digit_string)
        digit_string.present? && digit_string.length.in?([12, 13]) && digit_string.start_with?('55')
      end

      # 55 + DDD(2) + 9 + 8 digits when length is 12.
      def with_ninth_digit(digit_string)
        return unless international_mobile?(digit_string)
        return digit_string if digit_string.length == 13

        ddd = digit_string[2, 2]
        subscriber = digit_string[4, digit_string.length - 4]
        "55#{ddd}9#{subscriber}"
      end

      # Strip leading 9 after DDD when form is 55 + DDD + 9 + 8 digits.
      def without_ninth_digit(digit_string)
        return unless digit_string.to_s.length == 13

        ddd = digit_string[2, 2]
        ninth_digit = digit_string[4]
        subscriber = digit_string[5, 8]
        return unless ninth_digit == '9' && subscriber.to_s.length == 8

        "55#{ddd}#{subscriber}"
      end
    end
  end
end
