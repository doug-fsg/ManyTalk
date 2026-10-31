# frozen_string_literal: true

module AiAttendant
  class BehaviorScript
    STEP_MODES = %w[guide strict].freeze

    Step = Struct.new(:instruction, :completion_criterion, keyword_init: true) do
      def to_h
        {
          'instruction' => instruction,
          'completion_criterion' => completion_criterion
        }
      end
    end

    class << self
      def from_config(config)
        new(
          steps: normalize_steps(config.behavior_steps),
          mode: config.behavior_step_mode
        )
      end

      def normalize_steps(raw)
        Array(raw).filter_map do |item|
          case item
          when String
            text = item.strip
            next if text.blank?

            Step.new(instruction: text, completion_criterion: '')
          when Hash
            hash = item.stringify_keys
            instruction = (hash['instruction'] || hash['conteudo'] || hash['content']).to_s.strip
            next if instruction.blank?

            Step.new(
              instruction: instruction,
              completion_criterion: (hash['completion_criterion'] || hash['completionCriterion'] || '').to_s.strip
            )
          end
        end
      end
    end

    def initialize(steps:, mode: 'guide')
      @steps = steps
      @mode = STEP_MODES.include?(mode.to_s) ? mode.to_s : 'guide'
    end

    attr_reader :steps, :mode

    def strict?
      mode == 'strict'
    end

    def step_count
      steps.size
    end

    def prompt_section(step_index: 0)
      return if steps.empty?

      strict? ? strict_prompt_section(step_index) : guide_prompt_section
    end

    def preview_lines(step_index: 0)
      return [] if steps.empty?

      index = clamp_index(step_index)
      if strict?
        if index >= steps.size
          ['Roteiro concluído — conduza o fechamento ou encaminhe se necessário.']
        else
          step = steps[index]
          lines = ["PASSO #{format('%02d', index + 1)} de #{format('%02d', steps.size)} (atual)", step.instruction]
          lines << "Concluído quando: #{step.completion_criterion}" if step.completion_criterion.present?
          lines
        end
      else
        steps.each_with_index.flat_map do |step, i|
          block = ["PASSO #{format('%02d', i + 1)}: #{step.instruction}"]
          block << "Concluído quando: #{step.completion_criterion}" if step.completion_criterion.present?
          block
        end
      end
    end

    private

    def clamp_index(index)
      max = [steps.size - 1, 0].max
      [[index.to_i, 0].max, max].min
    end

    def guide_prompt_section
      blocks = steps.each_with_index.map do |step, index|
        lines = ["#PASSO #{format('%02d', index + 1)}: #{step.instruction}"]
        lines << "Concluído quando: #{step.completion_criterion}" if step.completion_criterion.present?
        lines.join("\n")
      end

      <<~TEXT.strip
        Passos
        #{blocks.join("\n\n")}

        Siga a ordem dos passos. Não avance para o passo seguinte antes de cumprir o passo anterior.
      TEXT
    end

    def strict_prompt_section(step_index)
      index = step_index.to_i
      return completed_strict_prompt if index >= steps.size

      index = clamp_index(index)
      step = steps[index]
      criterion = step.completion_criterion.presence || 'O objetivo deste passo estiver claramente atingido na conversa.'

      <<~TEXT.strip
        Roteiro de atendimento (modo estrito)
        Você está no PASSO #{format('%02d', index + 1)} de #{format('%02d', steps.size)}.
        Foque apenas neste passo. Não antecipe passos futuros.

        #PASSO #{format('%02d', index + 1)}: #{step.instruction}
        Considerar concluído quando: #{criterion}

        Quando este passo estiver concluído, chame a ferramenta complete_behavior_step com evidence resumindo o que o cliente confirmou.
      TEXT
    end

    def completed_strict_prompt
      <<~TEXT.strip
        Roteiro de atendimento (modo estrito)
        Todos os passos do roteiro foram concluídos. Ajude o cliente a fechar o atendimento ou use handoff_to_human se necessário.
      TEXT
    end
  end
end
