# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::BehaviorScript do
  describe '.normalize_steps' do
    it 'accepts strings and hashes' do
      steps = described_class.normalize_steps(
        [
          'Saudar',
          { 'instruction' => 'Qualificar', 'completion_criterion' => 'Cliente respondeu' },
          { 'conteudo' => 'Fechar' }
        ]
      )

      expect(steps.map(&:instruction)).to eq(['Saudar', 'Qualificar', 'Fechar'])
      expect(steps[1].completion_criterion).to eq('Cliente respondeu')
    end
  end

  describe '#prompt_section' do
    let(:config) do
      build(
        :ai_attendant_config,
        behavior_step_mode: mode,
        behavior_steps: [
          { 'instruction' => 'Saudar', 'completion_criterion' => 'Cliente respondeu oi' },
          { 'instruction' => 'Perguntar cidade', 'completion_criterion' => '' }
        ]
      )
    end

    context 'in guide mode' do
      let(:mode) { 'guide' }

      it 'lists all steps with order rule' do
        prompt = described_class.from_config(config).prompt_section(step_index: 0)

        expect(prompt).to include('#PASSO 01: Saudar')
        expect(prompt).to include('Concluído quando: Cliente respondeu oi')
        expect(prompt).to include('#PASSO 02: Perguntar cidade')
        expect(prompt).to include('Não avance para o passo seguinte')
      end
    end

    context 'in strict mode' do
      let(:mode) { 'strict' }

      it 'shows only the current step' do
        script = described_class.from_config(config)
        prompt = script.prompt_section(step_index: 1)

        expect(prompt).to include('PASSO 02 de 02')
        expect(prompt).to include('#PASSO 02: Perguntar cidade')
        expect(prompt).not_to include('#PASSO 01: Saudar')
        expect(prompt).to include('complete_behavior_step')
      end

      it 'shows completion message when all steps are done' do
        prompt = described_class.from_config(config).prompt_section(step_index: 2)

        expect(prompt).to include('Todos os passos')
      end
    end
  end
end
