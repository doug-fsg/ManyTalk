# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowListener do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:listener) { described_class.instance }

  describe '#message_created' do
    it 'calls handle_reply for incoming messages' do
      allow(WorkflowEnrollment).to receive(:handle_reply!)

      message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming)
      event = Events::Base.new('message_created', Time.zone.now, { message: message })

      listener.message_created(event)

      expect(WorkflowEnrollment).to have_received(:handle_reply!).with(conversation, message)
    end

    it 'calls handle_reply for outgoing messages so agent wait_for_reply can advance' do
      allow(WorkflowEnrollment).to receive(:handle_reply!)
      allow(WorkflowEnrollment).to receive(:cancel_for_agent_reply!)

      message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing)
      event = Events::Base.new('message_created', Time.zone.now, { message: message })

      listener.message_created(event)

      expect(WorkflowEnrollment).to have_received(:handle_reply!).with(conversation, message)
    end
  end
end
