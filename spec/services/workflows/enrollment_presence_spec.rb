# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::EnrollmentPresence do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation_a) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:conversation_b) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:settings) { Workflows::Constants::DEFAULT_SETTINGS.merge('enrollment_scope' => 'conversation') }
  let(:graph) do
    {
      'nodes' => [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'conversation_created', 'conditions' => [] } }
      ],
      'edges' => [],
      'settings' => settings
    }
  end
  let(:workflow) { create(:workflow, account: account, active: true, graph: graph) }

  before { account.enable_features!('workflows') }

  it 'blocks a new conversation enrollment when a contact-scoped enrollment is still in progress' do
    create(:workflow_enrollment, workflow: workflow, account: account, conversation: conversation_a,
                                 contact: contact, enrollment_scope: 'contact', status: 'active')

    expect(described_class.exists?(workflow, conversation_b)).to be true
  end

  it 'blocks contact-scope settings when any in-progress enrollment exists for the contact' do
    workflow.graph['settings']['enrollment_scope'] = 'contact'
    workflow.save!
    create(:workflow_enrollment, workflow: workflow, account: account, conversation: conversation_a,
                                 contact: contact, enrollment_scope: 'conversation', status: 'waiting')

    expect(described_class.exists?(workflow, conversation_b)).to be true
  end

  it 'allows a conversation-scoped enrollment on another conversation when no contact-scoped row exists' do
    create(:workflow_enrollment, workflow: workflow, account: account, conversation: conversation_a,
                                 contact: contact, enrollment_scope: 'conversation', status: 'active')

    expect(described_class.exists?(workflow, conversation_b)).to be false
  end
end
