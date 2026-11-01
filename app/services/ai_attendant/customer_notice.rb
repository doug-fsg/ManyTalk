# frozen_string_literal: true

module AiAttendant
  class CustomerNotice
    AUDIO = 'Não consigo ouvir áudio. Manda em texto que eu te respondo.'
    MEDIA = 'Não consigo ver figurinha nem GIF. Manda em texto que eu te respondo.'
    CLOSED = 'Estamos fora do horário de atendimento. Pode deixar sua mensagem que respondemos no próximo horário.'
    OFFICE_HOURS = 'Neste horário um atendente humano continua com você.'
    NO_CREDITS = 'Não consigo continuar o atendimento automático agora. Vou deixar sua conversa com um atendente.'
    RETRY = 'Tive um problema para responder agora. Pode enviar de novo?'

    IMMEDIATE_REASONS = %w[audio_unsupported unsupported_media no_credits].freeze
    NOTICE_TTL = 45

    def self.immediate?(reason)
      IMMEDIATE_REASONS.include?(reason.to_s)
    end

    def self.deliver!(message:, reason:)
      new(message: message, reason: reason).deliver!
    end

    def initialize(message:, reason:)
      @message = message
      @reason = reason.to_s
    end

    def deliver!
      return false unless claim_notice!

      if reason == 'no_credits'
        handoff_for_credits
      else
        send_text(text_for_reason)
      end
      true
    end

    private

    attr_reader :message, :reason

    def handoff_for_credits
      AiAttendant::HandoffService.new(
        conversation: message.conversation,
        summary: NO_CREDITS,
        config: config,
        customer_notice: NO_CREDITS
      ).perform
    end

    def send_text(text)
      AiAttendant::ResponseSender.new(
        conversation: message.conversation,
        sender: sender,
        text: text,
        config: config
      ).perform
    end

    def text_for_reason
      reason == 'audio_unsupported' ? AUDIO : MEDIA
    end

    def config
      @config ||= AiAttendantConfig.for_inbox(message.inbox_id).find_by(account_id: message.account_id)
    end

    def sender
      config.message_sender
    end

    def claim_notice!
      return false if config.blank?

      key = format(
        Redis::Alfred::AI_ATTENDANT_NOTICE,
        conversation_id: message.conversation_id,
        reason: reason
      )
      Redis::Alfred.set(key, '1', nx: true, ex: NOTICE_TTL)
    end
  end
end
