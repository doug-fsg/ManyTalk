# frozen_string_literal: true

module Workflows
  class PhoneNormalizer
    def self.normalize(raw)
      new(raw).normalize
    end

    def self.valid?(raw)
      normalize(raw).present?
    end

    def initialize(raw)
      @raw = raw
    end

    def normalize
      Campaigns::SpreadsheetPhoneNormalizer.normalize_to_e164(@raw)
    end

    def jid
      Campaigns::SpreadsheetPhoneNormalizer.normalize_to_jid(@raw)
    end

    def whatsapp_digits
      normalize&.delete('+')
    end
  end
end
