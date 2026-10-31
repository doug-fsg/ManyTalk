# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ProcessMessageJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:sender_user) { create(:user, account: account) }
  let(:config) do
    create(
      :ai_attendant_config,
      account: account,
      inbox_id: inbox.id,
      active: true,
      sender_user: sender_user,
      schedule_mode: 'always'
    )
  end
  let(:incoming_message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'Olá, preciso de ajuda')
  end
  let(:chat_service) { instance_double(AiAttendant::ChatService) }
  let(:response_sender) { instance_double(AiAttendant::ResponseSender, perform: 1) }
  let(:handoff_service) { instance_double(AiAttendant::HandoffService, perform: { assigned: true, assignee_id: 1 }) }

  def perform_job
    described_class.perform_now(account.id, inbox.id, conversation.id, [incoming_message.id])
  end

  def message_buffer
    AiAttendant::MessageBuffer.new(
      account_id: account.id,
      inbox_id: inbox.id,
      conversation_id: conversation.id
    )
  end

  def seed_buffer_as_follower
    message_buffer.push(message_id: incoming_message.id, content: incoming_message.content, debounce_seconds: 5)
    message_buffer.push(message_id: incoming_message.id + 1, content: 'segunda mensagem', debounce_seconds: 5)
  end

  after { message_buffer.clear! }

  before do
    config
    incoming_message
    allow(AiAttendant::WorkingHoursPolicy).to receive(:allow?).and_return(true)
    allow(AiAttendant::ChatService).to receive(:new).and_return(chat_service)
    allow(AiAttendant::ResponseSender).to receive(:new).and_return(response_sender)
    allow(AiAttendant::HandoffService).to receive(:new).and_return(handoff_service)
  end

  describe '#perform' do
    context 'when ChatService returns text' do
      before do
        allow(chat_service).to receive(:perform).and_return(
          { text: 'Olá, em que posso ajudar?', handoff: false, tokens: 120, credits_charged: 0.12 }
        )
      end

      it 'sends the reply via ResponseSender and records a successful run' do
        perform_job

        expect(AiAttendant::ChatService).to have_received(:new).with(
          hash_including(conversation: conversation, config: config, history: kind_of(Array))
        )
        expect(AiAttendant::ResponseSender).to have_received(:new).with(
          conversation: conversation,
          sender: sender_user,
          text: 'Olá, em que posso ajudar?',
          config: config
        )
        expect(response_sender).to have_received(:perform)
        expect(AiAttendant::HandoffService).not_to have_received(:new)

        run = AiAttendantRun.last
        expect(run).to have_attributes(
          account_id: account.id,
          conversation_id: conversation.id,
          inbox_id: inbox.id,
          status: 'success',
          tokens: 120
        )
      end
    end

    context 'when ChatService returns empty text without handoff' do
      before do
        allow(chat_service).to receive(:perform).and_return(
          { text: nil, handoff: false, tokens: 18, credits_charged: 0 }
        )
      end

      it 'sends the public fallback, calls HandoffService, and records an error run' do
        perform_job

        expect(AiAttendant::ResponseSender).to have_received(:new).with(
          conversation: conversation,
          sender: sender_user,
          text: 'Não consegui processar; vou chamar um atendente',
          config: config
        )
        expect(response_sender).to have_received(:perform)
        expect(AiAttendant::HandoffService).to have_received(:new).with(
          conversation: conversation,
          summary: 'Não consegui processar; vou chamar um atendente',
          config: config
        )
        expect(handoff_service).to have_received(:perform)

        run = AiAttendantRun.last
        expect(run.status).to eq('error')
        expect(run.inbox_id).to eq(inbox.id)
      end
    end

    context 'when working hours deny the turn' do
      before do
        allow(AiAttendant::WorkingHoursPolicy).to receive(:allow?).and_return(false)
      end

      it 'persists a skipped run and does not call ChatService or post a message' do
        expect(Messages::MessageBuilder).not_to receive(:new)

        perform_job

        expect(AiAttendant::ChatService).not_to have_received(:new)
        expect(AiAttendant::ResponseSender).not_to have_received(:new)
        expect(AiAttendant::HandoffService).not_to have_received(:new)

        run = AiAttendantRun.last
        expect(run).to have_attributes(
          account_id: account.id,
          conversation_id: conversation.id,
          inbox_id: inbox.id,
          status: 'skipped',
          skip_reason: 'working_hours'
        )
      end

      it 'clears the debounce buffer so a later push is :leader' do
        expect(seed_buffer_as_follower).to eq(:follower)

        perform_job

        expect(message_buffer.push(message_id: incoming_message.id + 2, content: 'depois do skip', debounce_seconds: 5)).to eq(:leader)
        expect(AiAttendant::ResponseSender).not_to have_received(:new)
        expect(AiAttendantRun.last.skip_reason).to eq('working_hours')
      end
    end

    context 'when quota is exceeded' do
      before do
        allow(PlatformAi::QuotaGuard).to receive(:allow?).and_return(false)
      end

      it 'skips without posting and clears the debounce buffer' do
        expect(seed_buffer_as_follower).to eq(:follower)

        perform_job

        expect(AiAttendant::ChatService).not_to have_received(:new)
        expect(AiAttendant::ResponseSender).not_to have_received(:new)
        expect(message_buffer.push(message_id: incoming_message.id + 2, content: 'depois do skip', debounce_seconds: 5)).to eq(:leader)
        expect(AiAttendantRun.last).to have_attributes(status: 'skipped', skip_reason: 'no_credits')
      end
    end
  end
end
