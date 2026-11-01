# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ChatService do
  let(:account) { create(:account, ai_credit_limit: 100, ai_credits_used: 1) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:config) { create(:ai_attendant_config, account: account, inbox_id: inbox.id) }
  let(:system) { 'Você é o atendente digital.' }
  let(:user) { '2026-10-29T18:00:00-03:00\nOlá' }
  let(:history) { [{ role: 'user', content: 'Oi' }, { role: 'assistant', content: 'Como posso ajudar?' }] }
  let(:handoff_service) { instance_double(AiAttendant::HandoffService, perform: { assigned: true, assignee_id: 9 }) }

  def perform_service
    described_class.new(
      conversation: conversation,
      config: config,
      system: system,
      user: user,
      history: history
    ).perform
  end

  def completion(content: nil, tool_calls: nil, total_tokens: 0)
    { content: content, tool_calls: tool_calls, total_tokens: total_tokens }
  end

  describe '#perform' do
    context 'when quota is exceeded' do
      before do
        account.update!(ai_credit_limit: 10, ai_credits_used: 10)
        allow(PlatformAi::ChatClient).to receive(:complete)
      end

      it 'returns empty result without calling ChatClient' do
        result = perform_service

        expect(PlatformAi::ChatClient).not_to have_received(:complete)
        expect(result).to eq(text: nil, handoff: false, tokens: 0, credits_charged: 0)
      end
    end

    context 'when the model returns text' do
      before do
        allow(PlatformAi::ChatClient).to receive(:complete).and_return(
          completion(content: 'Olá, em que posso ajudar?', total_tokens: 250)
        )
      end

      it 'returns the reply, tokens and credits charged from total_tokens / 1000' do
        result = perform_service

        expect(PlatformAi::ChatClient).to have_received(:complete).with(
          hash_including(
            messages: [
              { role: 'system', content: system },
              { role: 'user', content: 'Oi' },
              { role: 'assistant', content: 'Como posso ajudar?' },
              { role: 'user', content: user }
            ],
            tools: kind_of(Array)
          )
        )
        expect(result[:text]).to eq('Olá, em que posso ajudar?')
        expect(result[:handoff]).to be(false)
        expect(result[:tokens]).to eq(250)
        expect(result[:credits_charged]).to eq(BigDecimal('0.25'))
        expect(account.reload.ai_credits_used).to eq(1.25)
      end
    end

    context 'when the model returns empty content' do
      before do
        allow(PlatformAi::ChatClient).to receive(:complete).and_return(
          completion(content: nil, total_tokens: 18)
        )
      end

      it 'returns nil text without charging credits' do
        result = perform_service

        expect(result[:text]).to be_nil
        expect(result[:handoff]).to be(false)
        expect(result[:tokens]).to eq(18)
        expect(result[:credits_charged]).to eq(0)
        expect(account.reload.ai_credits_used).to eq(1)
      end
    end

    context 'when ChatClient raises RequestError' do
      before do
        allow(PlatformAi::ChatClient).to receive(:complete).and_raise(
          PlatformAi::ChatClient::RequestError.new('OpenAI chat completion failed with HTTP 500', status: 500)
        )
      end

      it 'returns nil text so the job can fallback' do
        result = perform_service

        expect(result).to eq(text: nil, handoff: false, tokens: 0, credits_charged: 0)
      end
    end

    context 'when ChatClient times out' do
      before do
        allow(PlatformAi::ChatClient).to receive(:complete).and_raise(Net::ReadTimeout)
      end

      it 'returns nil text without charging credits' do
        result = perform_service

        expect(result[:text]).to be_nil
        expect(result[:handoff]).to be(false)
        expect(result[:credits_charged]).to eq(0)
      end
    end

    context 'when the model calls handoff_to_human' do
      let(:tool_calls) do
        [
          {
            'id' => 'call_handoff',
            'type' => 'function',
            'function' => {
              'name' => 'handoff_to_human',
              'arguments' => { summary: 'Cliente pediu um humano' }.to_json
            }
          }
        ]
      end

      before do
        allow(AiAttendant::HandoffService).to receive(:new).and_return(handoff_service)
        allow(PlatformAi::ChatClient).to receive(:complete).and_return(
          completion(content: nil, tool_calls: tool_calls, total_tokens: 40)
        )
      end

      it 'runs HandoffService, stops, and does not send a follow-up model reply' do
        result = perform_service

        expect(AiAttendant::HandoffService).to have_received(:new).with(
          conversation: conversation,
          summary: 'Cliente pediu um humano',
          config: config
        )
        expect(handoff_service).to have_received(:perform)
        expect(result[:text]).to be_nil
        expect(result[:handoff]).to be(true)
        expect(result[:tokens]).to eq(40)
        expect(result[:credits_charged]).to eq(BigDecimal('0.04'))
        expect(PlatformAi::ChatClient).to have_received(:complete).once
      end
    end

    context 'when strict mode calls complete_behavior_step' do
      let(:config) do
        create(
          :ai_attendant_config,
          account: account,
          inbox_id: inbox.id,
          behavior_step_mode: 'strict',
          behavior_steps: [
            { 'instruction' => 'Saudar', 'completion_criterion' => 'Cliente respondeu' },
            { 'instruction' => 'Perguntar cidade', 'completion_criterion' => '' }
          ]
        )
      end
      let(:tool_calls) do
        [
          {
            'id' => 'call_step',
            'type' => 'function',
            'function' => {
              'name' => 'complete_behavior_step',
              'arguments' => { evidence: 'Cliente respondeu oi' }.to_json
            }
          }
        ]
      end

      before do
        allow(PlatformAi::ChatClient).to receive(:complete).and_return(
          completion(content: nil, tool_calls: tool_calls, total_tokens: 30),
          completion(content: 'Qual cidade você está?', total_tokens: 40)
        )
      end

      it 'advances persisted progress and includes the step tool' do
        result = perform_service

        stored = conversation.reload.additional_attributes['ai_behavior_progress']
        expect(stored['step_index']).to eq(1)
        expect(result[:text]).to eq('Qual cidade você está?')
        expect(PlatformAi::ChatClient).to have_received(:complete).with(
          hash_including(tools: array_including(hash_including(function: hash_including(name: 'complete_behavior_step'))))
        ).at_least(:once)
      end
    end

    context 'when sandbox is true' do
      let(:tool_calls) do
        [
          {
            'id' => 'call_handoff',
            'type' => 'function',
            'function' => {
              'name' => 'handoff_to_human',
              'arguments' => { summary: 'Cliente pediu um humano' }.to_json
            }
          }
        ]
      end

      def perform_sandbox
        described_class.new(
          conversation: conversation,
          config: config,
          system: system,
          user: user,
          history: history,
          sandbox: true
        ).perform
      end

      before do
        allow(AiAttendant::HandoffService).to receive(:new)
        allow(PlatformAi::QuotaGuard).to receive(:charge!)
        allow(PlatformAi::ChatClient).to receive(:complete).and_return(
          completion(content: nil, tool_calls: tool_calls, total_tokens: 40)
        )
      end

      it 'returns handoff true without charging quota or calling HandoffService' do
        result = perform_sandbox

        expect(PlatformAi::ChatClient).to have_received(:complete).once
        expect(AiAttendant::HandoffService).not_to have_received(:new)
        expect(PlatformAi::QuotaGuard).not_to have_received(:charge!)
        expect(result[:text]).to be_nil
        expect(result[:handoff]).to be(true)
        expect(result[:credits_charged]).to eq(0)
        expect(account.reload.ai_credits_used).to eq(1)
      end
    end
  end
end
