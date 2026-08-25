# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::EnrollmentFollowService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let!(:conversation_a) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let!(:conversation_b) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:workflow) { create(:workflow, account: account, active: true) }
  let(:enrollment) do
    create(:workflow_enrollment, workflow: workflow, account: account, conversation: conversation_a,
                                 contact: contact, enrollment_scope: 'contact', status: 'waiting')
  end

  before { account.enable_features!('workflows') }

  describe '#sync_to!' do
    it 'rebinds a contact-scoped enrollment to the new open conversation' do
      described_class.new.sync_to!(enrollment, conversation_b)
      expect(enrollment.reload.conversation_id).to eq(conversation_b.id)
    end

    it 'does not rebind conversation-scoped enrollments' do
      enrollment.update!(enrollment_scope: 'conversation')
      described_class.new.sync_to!(enrollment, conversation_b)
      expect(enrollment.reload.conversation_id).to eq(conversation_a.id)
    end
  end

  describe '.follow_to_conversation!' do
    it 'moves in-progress contact enrollments to the new conversation' do
      enrollment
      described_class.follow_to_conversation!(conversation_b)
      expect(enrollment.reload.conversation_id).to eq(conversation_b.id)
    end
  end

  describe '#ensure_actionable_conversation!' do
    it 'rebinds to the latest open conversation when the bound one is resolved' do
      enrollment
      conversation_a.resolved!
      described_class.new.ensure_actionable_conversation!(enrollment)
      expect(enrollment.reload.conversation_id).to eq(conversation_b.id)
    end
  end
end
