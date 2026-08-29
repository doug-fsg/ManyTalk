# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contacts::BrazilPhoneNormalizer do
  describe '.digits' do
    it 'strips non-digits' do
      expect(described_class.digits('+55 53 99067-484')).to eq('555399067484')
    end

    it 'returns nil for blank' do
      expect(described_class.digits('')).to be_nil
      expect(described_class.digits(nil)).to be_nil
    end
  end

  describe '.lookup_variants' do
    it 'returns both forms for DDD 41 without ninth digit' do
      expect(described_class.lookup_variants('554188887777')).to contain_exactly(
        '554188887777', '5541988887777'
      )
      expect(described_class.lookup_variants('+554188887777')).to contain_exactly(
        '554188887777', '5541988887777'
      )
    end

    it 'returns both forms for DDD 53 without ninth digit (user case)' do
      expect(described_class.lookup_variants('555399067484')).to contain_exactly(
        '555399067484', '5553999067484'
      )
      expect(described_class.lookup_variants('5399067484')).to include(
        '5399067484', '555399067484', '5553999067484'
      )
      # E.164 is already international — do not treat 10-digit national as local BR
      expect(described_class.lookup_variants('+555399067484')).to contain_exactly(
        '555399067484', '5553999067484'
      )
    end

    it 'returns both forms for DDD 53 with ninth digit' do
      expect(described_class.lookup_variants('5553999067484')).to contain_exactly(
        '5553999067484', '555399067484'
      )
    end

    it 'handles DDD 55 with and without ninth digit' do
      expect(described_class.lookup_variants('5555987654321')).to contain_exactly(
        '5555987654321', '555587654321'
      )
      expect(described_class.lookup_variants('555587654321')).to contain_exactly(
        '555587654321', '5555987654321'
      )
      expect(described_class.lookup_variants('55987654321')).to include(
        '55987654321', '5555987654321', '555587654321'
      )
    end

    it 'does not confuse country 55 with DDD 55 for local 10-digit input' do
      variants = described_class.lookup_variants('5512345678')
      expect(variants).to include('5512345678', '555512345678', '5555912345678')
    end

    it 'does not invent BR country code for short international E.164 numbers' do
      expect(described_class.lookup_variants('+2423423243')).to eq(['2423423243'])
      expect(described_class.e164_lookup_variants('+2423423243')).to eq(['+2423423243'])
    end

    it 'does not invent variants for non-Brazilian numbers' do
      expect(described_class.lookup_variants('919746334593')).to eq(['919746334593'])
    end

    it 'does not invent variants for invalid length' do
      expect(described_class.lookup_variants('559999999')).to eq(['559999999'])
    end
  end

  describe '.to_e164' do
    it 'prepends 55 for local 10/11 digit entries without rewriting the ninth digit' do
      expect(described_class.to_e164('5599067484')).to eq('+555599067484')
      expect(described_class.to_e164('55999067484')).to eq('+5555999067484')
    end

    it 'does not invent a country code for E.164 input' do
      expect(described_class.to_e164('+555599067484')).to eq('+555599067484')
    end
  end

  describe '.e164_lookup_variants' do
    it 'prefixes plus to digit variants' do
      expect(described_class.e164_lookup_variants('555399067484')).to contain_exactly(
        '+555399067484', '+5553999067484'
      )
    end
  end

  describe '.find_contact' do
    let(:account) { create(:account) }

    it 'finds contact by exact phone_number' do
      contact = create(:contact, account: account, phone_number: '+5555999067484')

      expect(described_class.find_contact(account: account, phone_number: '+5555999067484')).to eq(contact)
    end

    it 'finds contact by BR variant without ninth digit' do
      contact = create(:contact, account: account, phone_number: '+5555999067484')

      expect(described_class.find_contact(account: account, phone_number: '+555599067484')).to eq(contact)
    end

    it 'finds contact by BR variant with ninth digit' do
      contact = create(:contact, account: account, phone_number: '+555599067484')

      expect(described_class.find_contact(account: account, phone_number: '+5555999067484')).to eq(contact)
    end

    it 'prefers the contact with an open conversation in the inbox' do
      inbox = create(:inbox, account: account)
      duplicate = create(:contact, account: account, phone_number: '+555599067484')
      with_open = create(:contact, account: account, phone_number: '+5555999067484')
      create(:conversation, account: account, inbox: inbox, contact: with_open, status: :open)

      expect(
        described_class.find_contact(account: account, phone_number: '+555599067484', inbox: inbox)
      ).to eq(with_open)
      expect(duplicate).to be_present
    end
  end

  describe '.resolve_inbox_source_id' do
    before do
      stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
    end

    let!(:whatsapp_channel) { create(:channel_whatsapp, sync_templates: false, validate_provider_config: false) }
    let(:inbox) { whatsapp_channel.inbox }
    let(:with_nine) { '5541988887777' }
    let(:without_nine) { '554188887777' }

    it 'returns the incoming waid when no contact inbox exists' do
      expect(described_class.resolve_inbox_source_id(inbox: inbox, waid: with_nine)).to eq(with_nine)
      expect(described_class.resolve_inbox_source_id(inbox: inbox, waid: without_nine)).to eq(without_nine)
    end

    it 'reuses existing contact inbox when incoming has 9 and stored does not' do
      create(:contact_inbox, inbox: inbox, source_id: without_nine)

      expect(described_class.resolve_inbox_source_id(inbox: inbox, waid: with_nine)).to eq(without_nine)
    end

    it 'reuses existing contact inbox when incoming lacks 9 and stored has 9' do
      create(:contact_inbox, inbox: inbox, source_id: with_nine)

      expect(described_class.resolve_inbox_source_id(inbox: inbox, waid: without_nine)).to eq(with_nine)
    end

    it 'prefers exact source_id match when both variants exist' do
      create(:contact_inbox, inbox: inbox, source_id: without_nine)
      create(:contact_inbox, inbox: inbox, source_id: with_nine)

      expect(described_class.resolve_inbox_source_id(inbox: inbox, waid: with_nine)).to eq(with_nine)
      expect(described_class.resolve_inbox_source_id(inbox: inbox, waid: without_nine)).to eq(without_nine)
    end

    it 'does not alter non-brazilian waids' do
      expect(described_class.resolve_inbox_source_id(inbox: inbox, waid: '919746334593')).to eq('919746334593')
    end
  end
end
