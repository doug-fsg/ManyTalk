# frozen_string_literal: true

class AiAttendant::PromptBuilder
  TIMEZONE = 'America/Sao_Paulo'
  class << self
    def build_system(config:, conversation: nil, behavior_step_index: nil)
      new(config, conversation: conversation, behavior_step_index: behavior_step_index).build_system
    end

    def build_user(config:, combined_text:, at:)
      new(config).build_user(combined_text: combined_text, at: at)
    end
  end

  def initialize(config, conversation: nil, behavior_step_index: nil)
    @config = config
    @conversation = conversation
    @behavior_step_index_override = behavior_step_index
  end

  def build_system
    AiAttendant::ReferenceVariables.replace_legacy_tokens(
      system_sections.compact.join("\n\n"),
      attached_reference_files
    )
  end

  def build_user(combined_text:, at:)
    timestamp = at.in_time_zone(TIMEZONE).iso8601
    "#{timestamp}\n#{combined_text}"
  end

  private

  attr_reader :config, :conversation, :behavior_step_index_override

  def system_sections
    [
      identity_section,
      objective_section,
      duties_section,
      steps_section,
      company_context_section,
      files_section,
      topics_to_avoid_section,
      handoff_section,
      fixed_rules_section
    ]
  end

  def identity_section
    parts = []
    parts << "Nome: #{config.digital_agent_name}" if config.digital_agent_name.present?
    parts << "Quem você é: #{config.agent_role}" if config.agent_role.present?
    return if parts.empty?

    "Identidade\n#{parts.join("\n")}"
  end

  def objective_section
    return if config.agent_objective.blank?

    "Objetivo\n#{config.agent_objective}"
  end

  def duties_section
    return if config.agent_duties.blank?

    "Deveres\n#{config.agent_duties}"
  end

  def steps_section
    script = AiAttendant::BehaviorScript.from_config(config)
    step_index = behavior_step_index(script)
    script.prompt_section(step_index: step_index)
  end

  def behavior_step_index(script)
    return behavior_step_index_override.to_i unless behavior_step_index_override.nil?
    return 0 if conversation.blank?

    AiAttendant::BehaviorProgress.load(conversation: conversation).step_index
  end

  def company_context_section
    return if config.company_context.blank?

    "Contexto da empresa\n#{config.company_context}"
  end

  def files_section
    entries = AiAttendant::ReferenceVariables.entries(attached_reference_files)
    return if entries.empty?

    lines = [
      'Anexos',
      'As variáveis abaixo podem aparecer em qualquer parte das instruções.',
      'Para enviar o arquivo ao cliente, escreva um bloco contendo apenas a variável, sem nenhum outro texto.'
    ]
    entries.each do |entry|
      lines << "- #{entry[:token]} → #{entry[:filename]}"
    end
    lines.join("\n")
  end

  def topics_to_avoid_section
    topics = Array(config.topics_to_avoid).map(&:presence).compact
    return if topics.empty?

    "Temas a evitar\n#{topics.join("\n")}"
  end

  def handoff_section
    conditions = config.handoff_conditions.presence || 'Quando o cliente pedir para falar com uma pessoa.'

    <<~TEXT.strip
      Condições para encaminhar ao humano
      #{conditions}

      Se a mensagem do cliente se encaixar nessas condições, chame a ferramenta handoff_to_human.
      No summary, descreva o motivo em uma frase.
      Não diga ao cliente que a conversa foi transferida sem chamar essa ferramenta.
    TEXT
  end

  def fixed_rules_section
    <<~'RULES'.strip
      Regras fixas
      Não invente informações nem fale de produtos ou serviços que não foram informados.
      Escreva mensagens curtas.
      Separe blocos de mensagem com \n\n.
      Responda no idioma do cliente.
    RULES
  end

  def attached_reference_files
    return [] unless config.respond_to?(:reference_files) && config.reference_files.attached?

    config.reference_files.to_a
  end
end
