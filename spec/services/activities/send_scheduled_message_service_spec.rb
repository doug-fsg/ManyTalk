# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Activities::SendScheduledMessageService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox) { create(:inbox, account: account, channel_type: 'Channel::Api') }
  let(:activity) do
    create(
      :activity,
      :scheduled_message,
      account: account,
      user: user,
      assignee: user,
      contact: contact,
      inbox: inbox,
      message_content: 'Scheduled hello'
    )
  end

  describe '#perform' do
    it 'completes the activity after sending a session message' do
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      service = described_class.new(activity)
      allow(service).to receive(:find_or_create_conversation).and_return(conversation)
      allow(Messages::MessageBuilder).to receive(:new).and_return(
        instance_double(Messages::MessageBuilder, perform: create(:message, account: account, conversation: conversation))
      )

      service.perform

      expect(activity.reload.status).to eq('completed')
    end

    it 'marks activity as failed when whatsapp requires template but none is configured' do
      whatsapp_inbox = create(:inbox, account: account, channel_type: 'Channel::Whatsapp')
      wa_activity = create(
        :activity,
        :scheduled_message,
        account: account,
        user: user,
        assignee: user,
        contact: contact,
        inbox: whatsapp_inbox,
        message_content: 'Hello',
        metadata: { 'whatsapp' => { 'send_mode' => 'session_with_template_fallback' } }
      )
      contact_inbox = create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
      conversation = create(
        :conversation,
        account: account,
        inbox: whatsapp_inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )
      allow(conversation).to receive(:can_reply?).and_return(false)

      service = described_class.new(wa_activity)
      allow(service).to receive(:find_or_create_conversation).and_return(conversation)

      service.perform

      expect(wa_activity.reload.status).to eq('failed')
      expect(wa_activity.metadata['failure_reason']).to eq('template_required')
    end
  end
end
