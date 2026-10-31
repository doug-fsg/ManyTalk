# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::HandoffService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:sender_user) { create(:user, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:contact) { conversation.contact }
  let(:summary) { 'Cliente pediu para falar com um humano sobre a fatura.' }
  let(:handoff_customer_message) { 'Um atendente humano vai continuar daqui.' }
  let(:config) do
    create(
      :ai_attendant_config,
      account: account,
      inbox_id: inbox.id,
      sender_user: sender_user,
      handoff_customer_message: handoff_customer_message
    )
  end
  let(:assignment_service) { instance_double(AutoAssignment::AgentAssignmentService, perform: true) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    contact.update!(custom_attributes: { 'idioma' => 'pt-BR' })
    allow(AutoAssignment::AgentAssignmentService).to receive(:new).and_return(assignment_service)
  end

  def perform_handoff
    described_class.new(conversation: conversation, summary: summary, config: config).perform
  end

  describe '#perform' do
    context 'when an assignee is online' do
      before do
        allow(assignment_service).to receive(:perform) do
          conversation.update!(assignee: agent)
        end
      end

      it 'creates a private note, assigns the agent, and records ai_handoff_at' do
        freeze_time do
          result = perform_handoff

          expect(AutoAssignment::AgentAssignmentService).to have_received(:new).with(
            conversation: conversation,
            allowed_agent_ids: inbox.member_ids_with_assignment_capacity
          )

          private_note = conversation.messages.find_by(private: true)
          expect(private_note).to be_present
          expect(private_note.content).to include('[IA → Humano]')
          expect(private_note.content).to include(summary)
          expect(private_note.sender).to eq(sender_user)
          expect(private_note).to be_outgoing

          expect(conversation.reload).to be_open
          expect(conversation.assignee_id).to eq(agent.id)
          expect(contact.reload.custom_attributes['ai_handoff_at']).to eq(Time.current.iso8601)
          expect(contact.custom_attributes['idioma']).to eq('pt-BR')
          expect(conversation.messages.where(private: false, message_type: :outgoing)).to be_empty

          expect(result).to eq(assigned: true, assignee_id: agent.id)
        end
      end
    end

    context 'when no assignee is available' do
      it 'sends the public customer message and keeps the conversation unassigned' do
        freeze_time do
          result = perform_handoff

          expect(conversation.reload.assignee_id).to be_nil
          public_message = conversation.messages.find_by(private: false, message_type: :outgoing)
          expect(public_message).to be_present
          expect(public_message.content).to eq(handoff_customer_message)
          expect(public_message.sender).to eq(sender_user)
          expect(contact.reload.custom_attributes['ai_handoff_at']).to eq(Time.current.iso8601)
          expect(result).to eq(assigned: false, assignee_id: nil)
        end
      end

      it 'does not send a public message when handoff_customer_message is blank' do
        config.update!(handoff_customer_message: nil)

        perform_handoff

        expect(conversation.messages.where(private: false, message_type: :outgoing)).to be_empty
      end
    end
  end
end
