# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversations::ReusableConversationFinder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact) }
  let(:actor) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }

  def find_reusable
    described_class.new(contact_inbox: contact_inbox, actor: actor).find
  end

  it 'returns open unassigned conversation' do
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact,
                                         contact_inbox: contact_inbox, assignee: nil)

    expect(find_reusable).to eq(conversation)
  end

  it 'returns open conversation assigned to the actor' do
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact,
                                         contact_inbox: contact_inbox, assignee: actor)

    expect(find_reusable).to eq(conversation)
  end

  it 'does not return open conversation assigned to another agent' do
    create(:conversation, account: account, inbox: inbox, contact: contact,
                          contact_inbox: contact_inbox, assignee: other_agent)

    expect(find_reusable).to be_nil
  end

  it 'does not return resolved conversations' do
    create(:conversation, account: account, inbox: inbox, contact: contact,
                          contact_inbox: contact_inbox, status: :resolved)

    expect(find_reusable).to be_nil
  end

  it 'prefers the most recently updated reusable conversation' do
    older = create(:conversation, account: account, inbox: inbox, contact: contact,
                                  contact_inbox: contact_inbox, assignee: nil, updated_at: 2.days.ago)
    newer = create(:conversation, account: account, inbox: inbox, contact: contact,
                                  contact_inbox: contact_inbox, assignee: actor, updated_at: 1.hour.ago)

    expect(find_reusable).to eq(newer)
    expect(find_reusable).not_to eq(older)
  end
end
