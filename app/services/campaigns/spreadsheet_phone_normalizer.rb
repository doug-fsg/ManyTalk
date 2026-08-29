# frozen_string_literal: true

module Campaigns
  # Thin wrapper kept for existing callers. Canonical rules live in
  # Contacts::BrazilPhoneNormalizer — do not add or strip the Brazilian 9.
  class SpreadsheetPhoneNormalizer
    def self.normalize_to_e164(raw)
      new(raw).normalize_to_e164
    end

    def self.normalize_to_jid(raw)
      new(raw).normalize_to_jid
    end

    def initialize(raw)
      @raw = raw
    end

    def normalize_to_e164
      Contacts::BrazilPhoneNormalizer.to_e164(@raw)
    end

    def normalize_to_jid
      digits = Contacts::BrazilPhoneNormalizer.to_e164(@raw)&.delete('+')
      return if digits.blank?

      "#{digits}@s.whatsapp.net"
    end
  end
end
