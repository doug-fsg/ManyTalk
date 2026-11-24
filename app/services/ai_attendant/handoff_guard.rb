# frozen_string_literal: true

module AiAttendant
  class HandoffGuard
    MIN_TOPIC_LENGTH = 4
    CLAIMED_TRANSFER_SUMMARY = 'A IA afirmou que ia transferir sem chamar o encaminhamento.'
    CONDITION_HINTS = %w[
      reclam
      jurídico
      juridico
      advogad
      procon
      cancelament
      fraude
      process
    ].freeze

    TRANSFER_CLAIM = /
      \b(
        vou\ te\ (encaminhar|transferir)
        | te\ (encaminhei|transferi)
        | encaminhei\ (sua\ )?conversa
        | transferindo\ (você|voce|sua\ conversa)
        | um\ atendente\ (humano\ )?(vai|já|ja)
      )\b
    /ix

    Decision = Struct.new(:forced, :reason, :summary, keyword_init: true) do
      def forced?
        forced == true
      end
    end

    class << self
      def evaluate(text:, config:)
        new(text: text, config: config).evaluate
      end

      def claimed_transfer?(text)
        TRANSFER_CLAIM.match?(text.to_s)
      end
    end

    def initialize(text:, config:)
      @text = text.to_s
      @config = config
    end

    def evaluate
      return allow if text.blank?

      explicit_request || avoided_topic || condition_hint || allow
    end

    private

    attr_reader :text, :config

    def allow
      Decision.new(forced: false, reason: nil, summary: nil)
    end

    def force(reason, summary)
      Decision.new(forced: true, reason: reason, summary: summary)
    end

    def explicit_request
      return unless ExplicitHandoff.match?(text)

      force('explicit_request', ExplicitHandoff.summary)
    end

    def avoided_topic
      topic = matching_avoided_topic
      return if topic.blank?

      force('avoided_topic', "Cliente falou de um tema a evitar: #{topic}.")
    end

    def matching_avoided_topic
      Array(config&.topics_to_avoid).map { |item| item.to_s.strip }.find do |topic|
        next if topic.length < MIN_TOPIC_LENGTH

        haystack.include?(normalize(topic))
      end
    end

    def condition_hint
      conditions = config&.handoff_conditions.to_s
      return if conditions.blank?

      hint = CONDITION_HINTS.find do |token|
        normalize(conditions).include?(token) && haystack.include?(token)
      end
      return if hint.blank?

      force('handoff_condition', "A mensagem se encaixa nas condições de encaminhamento (#{hint}).")
    end

    def haystack
      @haystack ||= normalize(text)
    end

    def normalize(value)
      value.to_s.downcase
    end
  end
end
