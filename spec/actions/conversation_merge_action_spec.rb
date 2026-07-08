require 'rails_helper'

describe ConversationMergeAction do
  subject(:conversation_merge) do
    described_class.new(
      account: account,
      base_conversation: base_conversation,
      mergee_conversation: mergee_conversation
    ).perform
  end

  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:contact) { create(:contact, account: account) }
  let!(:base_contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let!(:mergee_contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let!(:base_conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: base_contact_inbox,
                          custom_attributes: { priority_level: 'high' })
  end
  let!(:mergee_conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: mergee_contact_inbox,
                          custom_attributes: { source: 'widget' })
  end
  let!(:agent) { create(:user, account: account, role: :agent) }

  before do
    Current.user = agent
    create(:message, conversation: base_conversation, account: account, inbox: inbox, created_at: 2.hours.ago)
    create(:message, conversation: mergee_conversation, account: account, inbox: inbox, created_at: 1.hour.ago)
    base_conversation.update_labels(%w[support])
    mergee_conversation.update_labels(%w[billing])
  end

  describe '#perform' do
    it 'moves messages from mergee conversation to base conversation' do
      mergee_message_count = mergee_conversation.messages.count
      base_message_count = base_conversation.messages.count

      conversation_merge

      expect(base_conversation.reload.messages.count).to eq(
        base_message_count + mergee_message_count
      )
      expect(Message.where(conversation_id: mergee_conversation.id).count).to eq(0)
    end

    it 'deletes mergee conversation' do
      mergee_id = mergee_conversation.id
      conversation_merge
      expect(Conversation.find_by(id: mergee_id)).to be_nil
    end

    it 'merges labels into base conversation' do
      base_conversation.update_labels(%w[Comercial])
      mergee_conversation.update_labels(%w[Inadimplente])

      conversation_merge

      expect(base_conversation.reload.label_list).to match_array(%w[Comercial Inadimplente])
    end

    it 'merges custom attributes with base taking precedence' do
      conversation_merge
      expect(base_conversation.reload.custom_attributes).to include(
        'priority_level' => 'high',
        'source' => 'widget'
      )
    end

    context 'when base conversation and mergee conversation are the same' do
      let(:mergee_conversation) { base_conversation }

      it 'does not delete conversation' do
        conversation_merge
        expect(base_conversation.reload).to be_present
      end
    end

    context 'when conversations belong to different inboxes' do
      let!(:other_inbox) { create(:inbox, account: account) }
      let!(:mergee_contact_inbox) { create(:contact_inbox, contact: contact, inbox: other_inbox) }
      let!(:mergee_conversation) do
        create(:conversation, account: account, inbox: other_inbox, contact: contact, contact_inbox: mergee_contact_inbox)
      end

      it 'raises an invalid merge error' do
        expect { conversation_merge }.to raise_error(CustomExceptions::ConversationMerge::InvalidMerge)
      end
    end

    context 'when conversations belong to different contacts' do
      let!(:other_contact) { create(:contact, account: account) }
      let!(:mergee_contact_inbox) { create(:contact_inbox, contact: other_contact, inbox: inbox) }
      let!(:mergee_conversation) do
        create(:conversation, account: account, inbox: inbox, contact: other_contact, contact_inbox: mergee_contact_inbox)
      end

      it 'raises an invalid merge error' do
        expect { conversation_merge }.to raise_error(CustomExceptions::ConversationMerge::InvalidMerge)
      end
    end

    context 'when conversations belong to a different account' do
      it 'raises an invalid merge error' do
        other_account = create(:account)
        expect do
          described_class.new(
            account: other_account,
            base_conversation: base_conversation,
            mergee_conversation: mergee_conversation
          ).perform
        end.to raise_error(CustomExceptions::ConversationMerge::InvalidMerge)
      end
    end

    context 'when mergee conversation has workflow enrollments' do
      let!(:workflow) { create(:workflow, account: account) }
      let!(:enrollment) do
        create(:workflow_enrollment, workflow: workflow, conversation: mergee_conversation, account: account, contact: contact)
      end

      it 'cancels and removes workflow enrollments on mergee conversation' do
        conversation_merge
        expect(WorkflowEnrollment.find_by(id: enrollment.id)).to be_nil
      end
    end
  end
end
