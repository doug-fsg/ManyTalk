# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ProcessMessageJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:sender) { config.message_sender }
  let(:config) do
    create(
      :ai_attendant_config,
      account: account,
      inbox_id: inbox.id,
      active: true,
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
    account.enable_features!('atendimento_ia_nativo')
    sender
    config
    incoming_message
    allow(AiAttendant::WorkingHoursPolicy).to receive(:allow?).and_return(true)
    allow(AiAttendant::ChatService).to receive(:new).and_return(chat_service)
    allow(AiAttendant::ResponseSender).to receive(:new).and_return(response_sender)
    allow(AiAttendant::HandoffService).to receive(:new).and_return(handoff_service)
  end

  describe '#perform' do
    it 'does nothing when atendimento_ia_nativo is disabled' do
      account.disable_features!('atendimento_ia_nativo')

      perform_job

      expect(AiAttendant::ChatService).not_to have_received(:new)
      expect(AiAttendant::ResponseSender).not_to have_received(:new)
    end

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
          sender: sender,
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

      it 'sends a retry and does not hand off' do
        perform_job

        expect(AiAttendant::ResponseSender).to have_received(:new).with(
          conversation: conversation,
          sender: sender,
          text: AiAttendant::CustomerNotice::RETRY,
          config: config
        )
        expect(response_sender).to have_received(:perform)
        expect(AiAttendant::HandoffService).not_to have_received(:new)

        run = AiAttendantRun.last
        expect(run.status).to eq('error')
        expect(run.inbox_id).to eq(inbox.id)
        expect(conversation.reload.additional_attributes['ai_handoff_at']).to be_blank
      end
    end

    context 'when working hours deny the turn' do
      before do
        allow(AiAttendant::WorkingHoursPolicy).to receive(:allow?).and_return(false)
      end

      it 'posts an out-of-office message and skips the model' do
        perform_job

        expect(AiAttendant::ChatService).not_to have_received(:new)
        expect(AiAttendant::ResponseSender).to have_received(:new).with(
          hash_including(text: AiAttendant::CustomerNotice::CLOSED)
        )
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
        expect(AiAttendantRun.last.skip_reason).to eq('working_hours')
      end
    end

    context 'when quota is exceeded' do
      before do
        allow(PlatformAi::QuotaGuard).to receive(:allow?).and_return(false)
      end

      it 'hands the conversation to a human and clears the debounce buffer' do
        expect(seed_buffer_as_follower).to eq(:follower)

        perform_job

        expect(AiAttendant::ChatService).not_to have_received(:new)
        expect(AiAttendant::HandoffService).to have_received(:new).with(
          hash_including(customer_notice: AiAttendant::CustomerNotice::NO_CREDITS)
        )
        expect(message_buffer.push(message_id: incoming_message.id + 2, content: 'depois do skip', debounce_seconds: 5)).to eq(:leader)
        expect(AiAttendantRun.last).to have_attributes(status: 'handoff', skip_reason: 'no_credits')
      end
    end
  end
end
