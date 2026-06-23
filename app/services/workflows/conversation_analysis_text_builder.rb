# frozen_string_literal: true

module Workflows
  class ConversationAnalysisTextBuilder
    TYPE_LABELS = {
      'executive_summary' => 'Resumo',
      'service_quality' => 'Qualidade do atendimento',
      'sales_opportunities' => 'Oportunidades de venda',
      'customer_sentiment' => 'Sentimento do cliente',
      'next_action' => 'Próxima ação'
    }.freeze

    pattr_initialize [:conversation!, :analysis_types!, :note_prefix]

    def build
      msgs = messages
      lines = [prefix_line, "Conversa ##{conversation.display_id}", "Total de mensagens: #{msgs.size}"]

      analysis_types.each do |type|
        lines << section_for(type, msgs)
      end

      lines.compact.join("\n")
    end

    private

    def prefix_line
      note_prefix.presence || 'Análise IA'
    end

    def messages
      @messages ||= conversation.messages
                              .where(private: false)
                              .order(created_at: :asc)
                              .limit(Constants::MAX_AI_ANALYSIS_MESSAGES)
                              .to_a
    end

    def section_for(type, msgs)
      label = TYPE_LABELS[type] || type.humanize
      case type
      when 'executive_summary'
        "#{label}: #{summarize(msgs)}"
      when 'service_quality'
        agent_msgs = msgs.count { |m| m.outgoing? }
        "#{label}: #{agent_msgs.positive? ? 'Atendente respondeu na conversa' : 'Sem resposta do atendente ainda'}"
      when 'sales_opportunities'
        "#{label}: #{keyword_hint(msgs, %w[comprar preço orçamento proposta pagamento])}"
      when 'customer_sentiment'
        "#{label}: #{keyword_hint(msgs, %w[obrigado ótimo ruim problema insatisfeito])}"
      when 'next_action'
        last_in = msgs.reverse.find(&:incoming?)
        "#{label}: #{last_in ? 'Responder ao cliente' : 'Aguardar mensagem do cliente'}"
      else
        nil
      end
    end

    def summarize(msgs)
      return 'Sem mensagens públicas na conversa.' if msgs.empty?

      last = msgs.last(3).map { |m| truncate(m.content) }.join(' | ')
      "Últimas interações: #{last}"
    end

    def keyword_hint(msgs, keywords)
      text = msgs.map(&:content).join(' ').downcase
      return 'Nenhum indicador claro nas mensagens' unless keywords.any? { |k| text.include?(k) }

      'Indícios encontrados nas mensagens recentes'
    end

    def truncate(text)
      str = text.to_s.strip
      return '(vazio)' if str.blank?

      str.length > 120 ? "#{str[0, 117]}..." : str
    end
  end
end
