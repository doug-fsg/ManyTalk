# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::KanbanEnrollmentConversations do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, :with_phone_number, account: account) }

  def whatsapp_inbox_for(account)
    create(:channel_whatsapp, account: account, validate_provider_config: false, sync_templates: false).inbox
  end

  describe '#resolve' do
    it 'returns the latest open conversation without creating another' do
      inbox = create(:inbox, account: account)
      older = create(:conversation, account: account, inbox: inbox, contact: contact, updated_at: 2.days.ago)
      newer = create(:conversation, account: account, inbox: inbox, contact: contact, updated_at: 1.hour.ago)

      expect { described_class.new(contact).resolve }.not_to change(Conversation, :count)
      expect(described_class.new(contact).resolve).to eq([newer])
      expect(described_class.new(contact).resolve).not_to include(older)
    end

    it 'does not create a conversation when the contact already has a resolved one' do
      inbox = create(:inbox, account: account)
      create(:conversation, account: account, inbox: inbox, contact: contact, status: :resolved)

      expect { described_class.new(contact).resolve }.not_to change(Conversation, :count)
      expect(described_class.new(contact).resolve).to eq([])
    end

    it 'reuses a resolved conversation when the workflow allows continuing after resolve' do
      inbox = create(:inbox, account: account)
      resolved = create(:conversation, account: account, inbox: inbox, contact: contact, status: :resolved)
      workflow = instance_double(Workflow, settings: { 'cancel_on_conversation_resolved' => false })

      expect { described_class.new(contact).resolve_for(workflow) }.not_to change(Conversation, :count)
      expect(described_class.new(contact).resolve_for(workflow)).to eq([resolved])
    end

    it 'does not reuse a resolved conversation when cancel on resolve is enabled' do
      inbox = create(:inbox, account: account)
      create(:conversation, account: account, inbox: inbox, contact: contact, status: :resolved)
      workflow = instance_double(Workflow, settings: { 'cancel_on_conversation_resolved' => true })

      expect(described_class.new(contact).resolve_for(workflow)).to eq([])
    end

    it 'creates a WhatsApp conversation when the contact has none and one WhatsApp inbox exists' do
      whatsapp_inbox = whatsapp_inbox_for(account)

      conversations = nil
      expect { conversations = described_class.new(contact).resolve }.to change(Conversation, :count).by(1)

      created = conversations.first
      expect(created.inbox).to eq(whatsapp_inbox)
      expect(created.contact).to eq(contact)
      expect(created.open?).to be(true)
      expect(created.additional_attributes['workflow_kanban_bootstrap']).to eq(true)
    end

    it 'reuses an existing WhatsApp contact inbox instead of guessing another inbox' do
      whatsapp_inbox = whatsapp_inbox_for(account)
      contact_inbox = create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)

      created = described_class.new(contact).resolve.first
      expect(created.contact_inbox).to eq(contact_inbox)
    end

    it 'does not create a conversation when the contact has no phone and no WhatsApp inbox link' do
      contact_without_phone = create(:contact, account: account, phone_number: nil)
      whatsapp_inbox_for(account)

      expect { described_class.new(contact_without_phone).resolve }.not_to change(Conversation, :count)
      expect(described_class.new(contact_without_phone).resolve).to eq([])
    end

    it 'does not guess an inbox when the account has more than one WhatsApp inbox' do
      whatsapp_inbox_for(account)
      whatsapp_inbox_for(account)

      expect { described_class.new(contact).resolve }.not_to change(Conversation, :count)
      expect(described_class.new(contact).resolve).to eq([])
    end

    it 'creates the conversation on the inbox configured in the Kanban action' do
      whatsapp_inbox_for(account)
      selected_inbox = whatsapp_inbox_for(account)
      workflow = create(
        :workflow,
        account: account,
        graph: {
          'nodes' => [
            {
              'id' => 'trigger_1',
              'type' => 'trigger',
              'data' => { 'event_name' => 'contact_kanban_stage_created', 'conditions' => [] }
            },
            {
              'id' => 'action_1',
              'type' => 'action',
              'data' => {
                'action_name' => 'send_message',
                'action_params' => ['Oi'],
                'inbox_id' => selected_inbox.id
              }
            }
          ],
          'edges' => [{ 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'action_1' }],
          'settings' => {}
        }
      )

      created = described_class.new(contact).resolve_for(workflow).first
      expect(created).to be_present
      expect(created.inbox).to eq(selected_inbox)
    end

    it 'creates the conversation on the inbox configured in Chamar cliente' do
      whatsapp_inbox_for(account)
      selected_inbox = whatsapp_inbox_for(account)
      workflow = create(
        :workflow,
        account: account,
        graph: {
          'nodes' => [
            {
              'id' => 'trigger_1',
              'type' => 'trigger',
              'data' => { 'event_name' => 'contact_kanban_stage_created', 'conditions' => [] }
            },
            {
              'id' => 'ai_1',
              'type' => 'ai_outreach',
              'data' => {
                'objective_preset' => 'reengagement',
                'prompt' => 'Retome o contato.',
                'inbox_id' => selected_inbox.id
              }
            }
          ],
          'edges' => [{ 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'ai_1' }],
          'settings' => {}
        }
      )

      created = described_class.new(contact).resolve_for(workflow).first
      expect(created).to be_present
      expect(created.inbox).to eq(selected_inbox)
    end
  end
end
