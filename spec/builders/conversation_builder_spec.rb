require 'rails_helper'

describe ConversationBuilder do
  let(:account) { create(:account) }
  let!(:sms_channel) { create(:channel_sms, account: account) }
  let!(:sms_inbox) { create(:inbox, channel: sms_channel, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: sms_inbox) }

  describe '#perform' do
    it 'creates conversation' do
      conversation = described_class.new(
        contact_inbox: contact_inbox,
        params: {}
      ).perform

      expect(conversation.contact_inbox_id).to eq(contact_inbox.id)
    end

    context 'when lock_to_single_conversation is true for inbox' do
      before do
        sms_inbox.update!(lock_to_single_conversation: true)
      end

      it 'creates conversation when existing conversation is not present' do
        conversation = described_class.new(
          contact_inbox: contact_inbox,
          params: {}
        ).perform

        expect(conversation.contact_inbox_id).to eq(contact_inbox.id)
      end

      it 'returns last from existing conversations when existing conversation is not present' do
        create(:conversation, contact_inbox: contact_inbox)
        existing_conversation = create(:conversation, contact_inbox: contact_inbox)
        conversation = described_class.new(
          contact_inbox: contact_inbox,
          params: {}
        ).perform

        expect(conversation.id).to eq(existing_conversation.id)
      end
    end

    context 'when an actor is present' do
      let(:actor) { create(:user, account: account) }
      let(:other_agent) { create(:user, account: account) }

      it 'reuses open unassigned conversation' do
        existing = create(:conversation, account: account, inbox: sms_inbox, contact: contact,
                                         contact_inbox: contact_inbox, assignee: nil)

        conversation = described_class.new(
          contact_inbox: contact_inbox,
          params: { assignee_id: actor.id },
          actor: actor
        ).perform

        expect(conversation.id).to eq(existing.id)
      end

      it 'reuses open conversation assigned to the actor' do
        existing = create(:conversation, account: account, inbox: sms_inbox, contact: contact,
                                         contact_inbox: contact_inbox, assignee: actor)

        conversation = described_class.new(
          contact_inbox: contact_inbox,
          params: { assignee_id: actor.id },
          actor: actor
        ).perform

        expect(conversation.id).to eq(existing.id)
      end

      it 'creates a new conversation when open conversation is assigned to another agent' do
        create(:conversation, account: account, inbox: sms_inbox, contact: contact,
                              contact_inbox: contact_inbox, assignee: other_agent)

        expect do
          described_class.new(
            contact_inbox: contact_inbox,
            params: { assignee_id: actor.id },
            actor: actor
          ).perform
        end.to change(Conversation, :count).by(1)
      end

      it 'creates a new conversation when only resolved conversations exist' do
        create(:conversation, account: account, inbox: sms_inbox, contact: contact,
                              contact_inbox: contact_inbox, status: :resolved)

        expect do
          described_class.new(
            contact_inbox: contact_inbox,
            params: { assignee_id: actor.id },
            actor: actor
          ).perform
        end.to change(Conversation, :count).by(1)
      end
    end
  end
end
