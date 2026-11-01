# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendantListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
  let(:message) do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :incoming,
      content_type: :text,
      private: false,
      content: 'Oi, preciso de ajuda'
    )
  end
  let(:event) { Events::Base.new('message.created', Time.zone.now, message: message) }

  def message_buffer
    AiAttendant::MessageBuffer.new(
      account_id: account.id,
      inbox_id: inbox.id,
      conversation_id: conversation.id
    )
  end

  before do
    account.enable_features!('atendimento_ia_nativo')
    create(:ai_attendant_config, account: account, inbox_id: inbox.id, active: true, debounce_seconds: 5)
  end

  after { message_buffer.clear! }

  describe '#message_created' do
    it 'enqueues ProcessMessageJob with debounce wait for an eligible incoming unassigned message' do
      freeze_time do
        expect { listener.message_created(event) }
          .to have_enqueued_job(AiAttendant::ProcessMessageJob)
          .with(account.id, inbox.id, conversation.id, [message.id])
          .at(5.seconds.from_now)
      end
    end

    it 'does not enqueue when the conversation is already assigned' do
      conversation.update!(assignee: create(:user, account: account, role: :agent))

      expect { listener.message_created(event) }
        .not_to have_enqueued_job(AiAttendant::ProcessMessageJob)
    end

    it 'replies to audio without calling the model' do
      message.attachments.create!(account_id: account.id, file_type: :audio)

      expect { listener.message_created(event) }
        .not_to have_enqueued_job(AiAttendant::ProcessMessageJob)

      reply = conversation.messages.outgoing.last
      expect(reply.content).to eq(AiAttendant::CustomerNotice::AUDIO)
      expect(reply.sender).to be_a(AgentBot)
    end

    it 'returns the conversation to the AI when the agent unassigns it' do
      agent = create(:user, account: account, role: :agent)
      conversation.update!(
        assignee: agent,
        additional_attributes: { 'ai_handoff_at' => Time.current.iso8601 }
      )
      conversation.update!(assignee: nil)
      updated = Events::Base.new(
        'conversation.updated',
        Time.zone.now,
        conversation: conversation,
        changed_attributes: { 'assignee_id' => [agent.id, nil] }
      )

      listener.conversation_updated(updated)

      expect(conversation.reload.additional_attributes).not_to have_key('ai_handoff_at')
      expect(conversation.assignee_id).to be_nil

      follow_up = Events::Base.new('message.created', Time.zone.now, message: message)
      expect { listener.message_created(follow_up) }
        .to have_enqueued_job(AiAttendant::ProcessMessageJob)
        .with(account.id, inbox.id, conversation.id, [message.id])
    end

    it 'keeps the handoff while the conversation stays with an agent' do
      agent = create(:user, account: account, role: :agent)
      conversation.update!(
        assignee: agent,
        additional_attributes: { 'ai_handoff_at' => Time.current.iso8601 }
      )
      updated = Events::Base.new(
        'conversation.updated',
        Time.zone.now,
        conversation: conversation,
        changed_attributes: { 'assignee_id' => [nil, agent.id] }
      )

      listener.conversation_updated(updated)

      expect(conversation.reload.additional_attributes).to have_key('ai_handoff_at')
    end

    it 'clears handoff when the conversation is resolved' do
      conversation.update!(additional_attributes: { 'ai_handoff_at' => Time.current.iso8601 })
      resolved = Events::Base.new('conversation.resolved', Time.zone.now, conversation: conversation)

      listener.conversation_resolved(resolved)

      expect(conversation.reload.additional_attributes).not_to have_key('ai_handoff_at')
    end

    it 'enqueues only once when a second rapid message is a buffer follower' do
      second_message = create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        message_type: :incoming,
        content_type: :text,
        private: false,
        content: 'sobre o pedido 123'
      )
      second_event = Events::Base.new('message.created', Time.zone.now, message: second_message)

      expect do
        listener.message_created(event)
        listener.message_created(second_event)
      end.to have_enqueued_job(AiAttendant::ProcessMessageJob).once
    end
  end

  it 'registers the singleton in AsyncDispatcher' do
    expect(AsyncDispatcher.new.listeners).to include(described_class.instance)
  end
end
