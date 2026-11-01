# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::PromptBuilder do
  let(:config) do
    create(
      :ai_attendant_config,
      digital_agent_name: 'Ana',
      agent_role: 'Atendente digital da loja',
      agent_duties: 'Tirar dúvidas e qualificar leads',
      agent_objective: 'Ajudar o cliente a encontrar o produto certo',
      behavior_steps: ['Saudar o cliente', 'Entender a necessidade'],
      company_context: 'Vendemos equipamentos industriais em São Paulo.',
      topics_to_avoid: ['política', 'concorrentes'],
      handoff_conditions: 'Quando o cliente pedir um humano'
    )
  end

  describe '.build_system' do
    it 'turns behavior_steps into numbered #PASSO lines' do
      prompt = described_class.build_system(config: config)

      expect(prompt).to include('#PASSO 01: Saudar o cliente')
      expect(prompt).to include('#PASSO 02: Entender a necessidade')
      expect(prompt).to include('Não avance para o passo seguinte')
    end

    it 'uses conversation progress in strict mode' do
      account = config.account
      inbox = create(:inbox, account: account)
      create(:ai_attendant_config_inbox, ai_attendant_config: config, inbox_id: inbox.id)
      config.update!(behavior_step_mode: 'strict')
      contact = create(:contact, account: account)
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      conversation.update!(
        additional_attributes: {
          'ai_behavior_progress' => { 'step_index' => 1 }
        }
      )

      prompt = described_class.build_system(config: config, conversation: conversation)

      expect(prompt).to include('PASSO 02 de 02')
      expect(prompt).not_to include('#PASSO 01: Saudar o cliente')
    end

    it 'includes company_context and topics_to_avoid' do
      prompt = described_class.build_system(config: config)

      expect(prompt).to include('Vendemos equipamentos industriais em São Paulo.')
      expect(prompt).to include('política')
      expect(prompt).to include('concorrentes')
    end

    it 'includes identity, objective, duties, handoff_conditions and fixed rules' do
      prompt = described_class.build_system(config: config)

      expect(prompt).to include('Ana')
      expect(prompt).to include('Atendente digital da loja')
      expect(prompt).to include('Tirar dúvidas e qualificar leads')
      expect(prompt).to include('Ajudar o cliente a encontrar o produto certo')
      expect(prompt).to include('Quando o cliente pedir um humano')
      expect(prompt).to include('handoff_to_human')
      expect(prompt).to include('não invent').or include('Não invent')
      expect(prompt).to include('\n\n')
    end

    it 'replaces [REFERENCIA] with the named file variable' do
      config.company_context = 'Catálogo: [REFERENCIA]'
      config.save!
      config.reference_files.attach(
        io: File.open(Rails.root.join('spec/assets/avatar.png')),
        filename: 'catalogo.png',
        content_type: 'image/png'
      )

      prompt = described_class.build_system(config: config)

      expect(prompt).to include('{{anexo:catalogo}}')
      expect(prompt).not_to include('[REFERENCIA]')
    end

    it 'lists named file variables instead of raw URLs' do
      config.save!
      config.reference_files.attach(
        io: File.open(Rails.root.join('spec/assets/avatar.png')),
        filename: 'tabela.png',
        content_type: 'image/png'
      )

      prompt = described_class.build_system(config: config)

      expect(prompt).to include('{{anexo:tabela}}')
      expect(prompt).to include('tabela.png')
      expect(prompt).to include('Anexos')
    end
  end

  describe '.build_user' do
    it 'includes America/Sao_Paulo timestamp and concatenated text' do
      at = Time.utc(2026, 10, 29, 21, 0, 0)

      prompt = described_class.build_user(
        config: config,
        combined_text: 'Oi, quero um orçamento',
        at: at
      )

      expected_time = at.in_time_zone('America/Sao_Paulo').iso8601
      expect(prompt).to include(expected_time)
      expect(prompt).to include('Oi, quero um orçamento')
    end
  end
end
