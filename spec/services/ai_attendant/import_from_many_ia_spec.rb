# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ImportFromManyIa do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  # Payload mínimo many-ia (espelho camelCase do legado). Sem tokens/secrets.
  # id → many_ia_config_id (chave de upsert)
  # inboxId → inbox_id
  # isActive → active
  # detectarIdioma → detect_language
  # nomeAtendenteDigital → digital_agent_name
  # quemEhAtendente → agent_role
  # oQueAtendenteFaz → agent_duties
  # objetivoAtendente → agent_objective
  # comoAtendenteDeve → behavior_steps (array de strings; unwrap { conteudo }; string JSON parseada)
  # informacoesEmpresa → company_context (entra no prompt; spec normativa)
  # temasEvitar → topics_to_avoid (strings ou objetos { conteudo } / { tema })
  # condicoesAtendimento → handoff_conditions
  # horarioAtendimento → schedule_mode
  def many_ia_payload(overrides = {})
    {
      'id' => 'many-ia-cfg-1',
      'inboxId' => inbox.id,
      'isActive' => true,
      'detectarIdioma' => true,
      'nomeAtendenteDigital' => 'Lia Digital',
      'quemEhAtendente' => 'Atendente virtual',
      'oQueAtendenteFaz' => 'Tira dúvidas',
      'objetivoAtendente' => 'Qualificar leads',
      'comoAtendenteDeve' => ['Cumprimentar', 'Perguntar o nome'],
      'informacoesEmpresa' => 'Somos a Manytalks',
      'temasEvitar' => [{ 'conteudo' => 'preço interno' }, 'política salarial'],
      'condicoesAtendimento' => 'Quando pedir humano',
      'horarioAtendimento' => 'Atender 24h por dia'
    }.merge(overrides)
  end

  describe '.call' do
    it 'maps nomeAtendenteDigital and creates a config' do
      config = described_class.call(account: account, payload: many_ia_payload)

      expect(config).to be_persisted
      expect(config.account_id).to eq(account.id)
      expect(config.inbox_ids).to eq([inbox.id])
      expect(config.digital_agent_name).to eq('Lia Digital')
      expect(config.many_ia_config_id).to eq('many-ia-cfg-1')
      expect(config.active).to be(true)
      expect(config.detect_language).to be(true)
      expect(config.agent_role).to eq('Atendente virtual')
      expect(config.agent_duties).to eq('Tira dúvidas')
      expect(config.agent_objective).to eq('Qualificar leads')
      expect(config.behavior_steps).to eq([
                                            { 'instruction' => 'Cumprimentar', 'completion_criterion' => '' },
                                            { 'instruction' => 'Perguntar o nome', 'completion_criterion' => '' }
                                          ])
      expect(config.company_context).to eq('Somos a Manytalks')
      expect(config.topics_to_avoid).to eq(['preço interno', 'política salarial'])
      expect(config.handoff_conditions).to eq('Quando pedir humano')
      expect(config.sender_agent_bot).to be_present
      expect(config.sender_agent_bot.name).to eq('Lia Digital')
      expect(config.sender_agent_bot.bot_config['kind']).to eq('ai_attendant')
      expect(account.users).to be_empty
    end

    it 'maps horarioAtendimento to schedule_mode' do
      always = described_class.call(
        account: account,
        payload: many_ia_payload('horarioAtendimento' => 'Atender 24h por dia')
      )
      expect(always.schedule_mode).to eq('always')

      other_inbox = create(:inbox, account: account)
      within = described_class.call(
        account: account,
        payload: many_ia_payload(
          'id' => 'many-ia-cfg-within',
          'inboxId' => other_inbox.id,
          'horarioAtendimento' => 'Dentro do horário de atendimento'
        )
      )
      expect(within.schedule_mode).to eq('within_inbox_hours')

      third_inbox = create(:inbox, account: account)
      outside = described_class.call(
        account: account,
        payload: many_ia_payload(
          'id' => 'many-ia-cfg-outside',
          'inboxId' => third_inbox.id,
          'horarioAtendimento' => 'Fora do horário de atendimento'
        )
      )
      expect(outside.schedule_mode).to eq('outside_inbox_hours')
    end

    it 'wraps or parses comoAtendenteDeve when it is a string' do
      config = described_class.call(
        account: account,
        payload: many_ia_payload('comoAtendenteDeve' => '["Passo 1","Passo 2"]')
      )

      expect(config.behavior_steps).to eq([
                                            { 'instruction' => 'Passo 1', 'completion_criterion' => '' },
                                            { 'instruction' => 'Passo 2', 'completion_criterion' => '' }
                                          ])
    end

    it 'unwraps conteudo objects from comoAtendenteDeve into string steps' do
      config = described_class.call(
        account: account,
        payload: many_ia_payload(
          'comoAtendenteDeve' => [{ 'conteudo' => 'Cumprimentar' }, { 'conteudo' => 'Perguntar o nome' }]
        )
      )

      expect(config.behavior_steps).to eq([
                                            { 'instruction' => 'Cumprimentar', 'completion_criterion' => '' },
                                            { 'instruction' => 'Perguntar o nome', 'completion_criterion' => '' }
                                          ])
    end

    it 'unwraps string JSON arrays of conteudo objects from comoAtendenteDeve' do
      config = described_class.call(
        account: account,
        payload: many_ia_payload('comoAtendenteDeve' => '[{"conteudo":"Passo 1"},{"conteudo":"Passo 2"}]')
      )

      expect(config.behavior_steps).to eq([
                                            { 'instruction' => 'Passo 1', 'completion_criterion' => '' },
                                            { 'instruction' => 'Passo 2', 'completion_criterion' => '' }
                                          ])
    end

    it 'accepts tema or conteudo keys on temasEvitar objects' do
      config = described_class.call(
        account: account,
        payload: many_ia_payload(
          'temasEvitar' => [{ 'tema' => 'preço interno' }, { 'conteudo' => 'política salarial' }]
        )
      )

      expect(config.topics_to_avoid).to eq(['preço interno', 'política salarial'])
    end

    it 'rejects missing or blank many-ia id' do
      baseline = AiAttendantConfig.count

      expect do
        described_class.call(account: account, payload: many_ia_payload.except('id'))
      end.to raise_error(AiAttendant::ImportFromManyIa::Error, /id is required/)

      expect do
        described_class.call(account: account, payload: many_ia_payload('id' => ''))
      end.to raise_error(AiAttendant::ImportFromManyIa::Error, /id is required/)

      expect do
        described_class.call(account: account, payload: many_ia_payload('id' => '   '))
      end.to raise_error(AiAttendant::ImportFromManyIa::Error, /id is required/)

      expect(AiAttendantConfig.count).to eq(baseline)
      expect(account.ai_attendant_configs.where(many_ia_config_id: '')).to be_empty
    end

    it 'rejects missing or foreign inboxId' do
      foreign_inbox = create(:inbox)
      baseline = AiAttendantConfig.count

      expect do
        described_class.call(account: account, payload: many_ia_payload.except('inboxId'))
      end.to raise_error(AiAttendant::ImportFromManyIa::Error, /inboxId must belong to the account/)

      expect do
        described_class.call(
          account: account,
          payload: many_ia_payload('inboxId' => foreign_inbox.id)
        )
      end.to raise_error(AiAttendant::ImportFromManyIa::Error, /inboxId must belong to the account/)

      expect(AiAttendantConfig.count).to eq(baseline)
    end

    it 'does not duplicate on the same many_ia_config_id' do
      described_class.call(account: account, payload: many_ia_payload)

      expect do
        updated = described_class.call(
          account: account,
          payload: many_ia_payload(
            'nomeAtendenteDigital' => 'Lia Atualizada',
            'horarioAtendimento' => 'Dentro do horário de atendimento'
          )
        )
        expect(updated.digital_agent_name).to eq('Lia Atualizada')
        expect(updated.schedule_mode).to eq('within_inbox_hours')
        expect(updated.sender_agent_bot).to be_present
      end.not_to change(AiAttendantConfig, :count)
    end
  end
end
