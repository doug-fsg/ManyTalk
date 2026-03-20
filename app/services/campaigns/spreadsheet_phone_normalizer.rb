# frozen_string_literal: true

module Campaigns
  # Normaliza números de telefone vindos de planilhas em campanhas one-off de disparo em massa.
  # Aplica regras específicas: internacional (+), Brasil (DDD, 9 vs 8 dígitos conforme DDD).
  class SpreadsheetPhoneNormalizer
    def self.normalize_to_e164(raw)
      new(raw).normalize_to_e164
    end

    def self.normalize_to_jid(raw)
      new(raw).normalize_to_jid
    end

    def initialize(raw)
      @raw = raw.to_s.strip
    end

    def normalize_to_e164
      digits = normalized_digits
      return nil if digits.blank?

      result = "+#{digits}"
      Rails.logger.error("[SpreadsheetPhoneNormalizer] OK: raw=#{@raw.inspect} => #{result}")
      result
    end

    def normalize_to_jid
      digits = normalized_digits
      return nil if digits.blank?

      "#{digits}@s.whatsapp.net"
    end

    private

    def normalized_digits
      if @raw.blank?
        Rails.logger.error("[SpreadsheetPhoneNormalizer] input vazio ou nil")
        return nil
      end

      # Internacional: começa com +
      if @raw.start_with?('+')
        result = international_digits
        Rails.logger.error("[SpreadsheetPhoneNormalizer] internacional: raw=#{@raw.inspect} => #{result.inspect}") if result.blank?
        return result
      end

      # Brasil
      result = brazil_digits
      Rails.logger.error("[SpreadsheetPhoneNormalizer] Brasil: raw=#{@raw.inspect} => #{result.inspect} (digits_len=#{@raw.gsub(/\D/, '').length})") if result.blank?
      result
    end

    def international_digits
      digits = @raw.gsub(/\D/, '')
      digits.presence
    end

    def brazil_digits
      digits = @raw.gsub(/\D/, '')

      # Remove 55 se tiver 12 ou 13 dígitos começando com 55
      if digits.length.in?(12..13) && digits.start_with?('55')
        digits = digits[2..]
      end

      # Precisa ter 10 ou 11 dígitos (DDD + número)
      unless digits.length.in?(10..11)
        Rails.logger.error("[SpreadsheetPhoneNormalizer] Brasil inválido: digits_len=#{digits.length} (esperado 10 ou 11)")
        return nil
      end

      ddd = digits[0, 2]
      number_part = digits[2..]
      last8 = number_part[-8..]

      if last8.blank? || last8.length < 8
        Rails.logger.error("[SpreadsheetPhoneNormalizer] Brasil: last8 inválido ddd=#{ddd} number_part=#{number_part}")
        return nil
      end

      if ddd.to_i < 31
        "55#{ddd}9#{last8}"
      else
        "55#{ddd}#{last8}"
      end
    end
  end
end
