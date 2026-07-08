require 'rails_helper'

RSpec.describe WorkflowListener do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:listener) { described_class.instance }

  describe '#message_created' do
    it 'ignores external echo messages' do
      message = create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        message_type: :outgoing,
        content_attributes: { external_echo: true }
      )

      event = Events::Base.new('message_created', Time.zone.now, { message: message })

      expect(Workflows::ProcessEventJob).not_to receive(:perform_later)
      expect(WorkflowEnrollment).not_to receive(:handle_reply!)
      expect(WorkflowEnrollment).not_to receive(:cancel_for_agent_reply!)

      listener.message_created(event)
    end
  end
end
