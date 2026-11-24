# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::HandoffGuard do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:config) do
    create(
      :ai_attendant_config,
      account: account,
      inbox_id: inbox.id,
      topics_to_avoid: ['preço interno', 'RH'],
      handoff_conditions: 'Quando o cliente reclamar ou o assunto for jurídico.'
    )
  end

  describe '.evaluate' do
    it 'forces handoff on an explicit human request' do
      decision = described_class.evaluate(text: 'quero falar com um atendente', config: config)

      expect(decision).to be_forced
      expect(decision.reason).to eq('explicit_request')
      expect(decision.summary).to eq(AiAttendant::ExplicitHandoff.summary)
    end

    it 'forces handoff when the message mentions a topic to avoid' do
      decision = described_class.evaluate(text: 'me passa o preço interno da tabela', config: config)

      expect(decision).to be_forced
      expect(decision.reason).to eq('avoided_topic')
      expect(decision.summary).to include('preço interno')
    end

    it 'ignores topics shorter than the minimum length' do
      decision = described_class.evaluate(text: 'trabalho no RH da empresa', config: config)

      expect(decision).not_to be_forced
    end

    it 'forces handoff when a configured condition hint appears in the message' do
      decision = described_class.evaluate(text: 'quero abrir um processo jurídico', config: config)

      expect(decision).to be_forced
      expect(decision.reason).to eq('handoff_condition')
    end

    it 'allows ordinary questions' do
      decision = described_class.evaluate(text: 'qual o horário de atendimento?', config: config)

      expect(decision).not_to be_forced
    end
  end

  describe '.claimed_transfer?' do
    it 'detects a transfer claim in the model reply' do
      expect(described_class.claimed_transfer?('Vou te encaminhar para um atendente agora.')).to be(true)
      expect(described_class.claimed_transfer?('Posso te ajudar com o pedido.')).to be(false)
    end
  end
end
