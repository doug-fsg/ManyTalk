# frozen_string_literal: true

# Deterministic pre-filter for AI intent classification.
# Only uses structural signals — completely language-agnostic.
# ADR: No word lists, no length limits. See plan for rationale.
module Workflows
  class IntentMessagePrefilter
    EMOJI_PATTERN = /\A[\p{Emoji}\p{So}\uFE0F\u200D]+\z/u.freeze
    PUNCTUATION_ONLY_PATTERN = /\A[?!.]{3,}\z/.freeze

    def initialize(content, seen_normalized: [])
      @content = content.to_s
      @seen_normalized = Array(seen_normalized)
    end

    def skip?
      skip_reason.present?
    end

    def skip_reason
      return :empty if empty?
      return :punctuation_only if punctuation_only?
      return :emoji_only if emoji_only?
      return :identical_repeat if identical_repeat?

      nil
    end

    def normalized
      @normalized ||= @content.unicode_normalize(:nfkc).downcase.gsub(/\s+/, ' ').strip
    end

    private

    def empty?
      @content.blank?
    end

    def punctuation_only?
      PUNCTUATION_ONLY_PATTERN.match?(normalized)
    end

    def emoji_only?
      stripped = @content.gsub(/\s/, '')
      stripped.present? && EMOJI_PATTERN.match?(stripped)
    end

    def identical_repeat?
      @seen_normalized.include?(normalized)
    end
  end
end
