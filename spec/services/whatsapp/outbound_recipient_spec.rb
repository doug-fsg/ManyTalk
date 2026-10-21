# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::OutboundRecipient do
  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  let(:channel) { create(:channel_whatsapp, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { channel.inbox }

  def build_contact_inbox(source_id:, phone_number:)
    contact = create(:contact, account: inbox.account, phone_number: phone_number)
    create(:contact_inbox, inbox: inbox, contact: contact, source_id: source_id)
  end

  describe '#call' do
    it 'returns source_id when it matches contact phone digits' do
      contact_inbox = build_contact_inbox(source_id: '5511999999999', phone_number: '+5511999999999')

      expect(described_class.new(contact_inbox: contact_inbox).call).to eq('5511999999999')
    end

    it 'prefers 13-digit BR mobile when source_id is missing the ninth digit (AGTU case)' do
      contact_inbox = build_contact_inbox(source_id: '559581072593', phone_number: '+5595981072593')

      expect(described_class.new(contact_inbox: contact_inbox).call).to eq('5595981072593')
    end

    it 'prefers 13-digit BR mobile for second AGTU mismatch sample' do
      contact_inbox = build_contact_inbox(source_id: '559492797987', phone_number: '+5594992797987')

      expect(described_class.new(contact_inbox: contact_inbox).call).to eq('5594992797987')
    end

    it 'keeps source_id when contact phone is a different number' do
      contact_inbox = build_contact_inbox(source_id: '551188887777', phone_number: '+5511999999999')

      expect(described_class.new(contact_inbox: contact_inbox).call).to eq('551188887777')
    end

    it 'keeps source_id when contact has no phone_number' do
      contact = create(:contact, account: inbox.account, phone_number: nil)
      contact_inbox = create(:contact_inbox, inbox: inbox, contact: contact, source_id: '551188887777')

      expect(described_class.new(contact_inbox: contact_inbox).call).to eq('551188887777')
    end

    it 'uses contact phone digits when source_id is a UUID (legacy/corrupt row)' do
      contact = create(:contact, account: inbox.account, phone_number: '+5511987654321')
      contact_inbox = create(:contact_inbox, inbox: inbox, contact: contact, source_id: '5511987654321')
      # WhatsApp validates digits-only source_id; simulate a legacy UUID via update_column.
      contact_inbox.update_column(:source_id, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890') # rubocop:disable Rails/SkipsModelValidations

      expect(described_class.new(contact_inbox: contact_inbox).call).to eq('5511987654321')
    end

    it 'keeps non-digit source_ids unchanged' do
      contact = create(:contact, account: inbox.account, phone_number: '+5511987654321')
      contact_inbox = create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'whatsapp:group@g.us')

      expect(described_class.new(contact_inbox: contact_inbox).call).to eq('whatsapp:group@g.us')
    end

    it 'prefers contact 13-digit form when source_id already has nine' do
      contact_inbox = build_contact_inbox(source_id: '5595981072593', phone_number: '+5595981072593')

      expect(described_class.new(contact_inbox: contact_inbox).call).to eq('5595981072593')
    end
  end
end
