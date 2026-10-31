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
