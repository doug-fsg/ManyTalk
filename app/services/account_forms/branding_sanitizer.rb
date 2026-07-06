# frozen_string_literal: true

module AccountForms
  class BrandingSanitizer
    HEX_COLOR = /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/
    LOGO_ALIGNMENTS = %w[left center right].freeze
    ALLOWED_KEYS = %w[
      primary_color
      background_color
      page_background_color
      text_color
      logo_url
      logo_alignment
      logo_expand
      header_title
      header_description
      submit_label
    ].freeze

    def self.call(branding)
      new(branding).call
    end

    def initialize(branding)
      @branding = branding
    end

    def call
      return AccountForm::DEFAULT_BRANDING.deep_dup unless @branding.is_a?(Hash)

      source = @branding.stringify_keys
      defaults = AccountForm::DEFAULT_BRANDING
      result = {}

      ALLOWED_KEYS.each do |key|
        result[key] = sanitize_value(key, source[key], defaults[key])
      end

      result
    end

    private

    def sanitize_value(key, value, default)
      case key
      when 'primary_color', 'background_color', 'page_background_color', 'text_color'
        sanitize_hex(value, default)
      when 'logo_alignment'
        alignment = value.to_s
        LOGO_ALIGNMENTS.include?(alignment) ? alignment : (default || 'center')
      when 'logo_expand'
        ActiveModel::Type::Boolean.new.cast(value) == true
      when 'logo_url'
        sanitize_logo_url(value, default)
      when 'header_title', 'header_description', 'submit_label'
        sanitize_text(value, default)
      else
        default
      end
    end

    def sanitize_hex(value, default)
      hex = value.to_s.strip
      return default if hex.blank?
      return default unless hex.match?(HEX_COLOR)

      hex.downcase
    end

    def sanitize_logo_url(value, default)
      url = value.to_s.strip
      return default.to_s if url.blank?
      return url if url.start_with?('/')
      return url if url.match?(/\Ahttps?:\/\//i)

      default.to_s
    end

    def sanitize_text(value, default)
      text = ActionController::Base.helpers.strip_tags(value.to_s).strip
      text.presence || default.to_s
    end
  end
end
