# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaigns::AudienceResolver do
  let(:account) { create(:account) }
  let(:label) { create(:label, account: account) }
  let(:campaign) do
    create(:campaign,
           account: account,
           campaign_type: :one_off,
           audience: [{ 'type' => 'Label', 'id' => label.id }])
  end

  subject(:resolver) { described_class.new(campaign: campaign) }

  describe '#deliverable_contacts' do
    context 'with label audience' do
      let!(:contact_with_phone) do
        create(:contact, account: account, phone_number: '+5511999990001')
      end
      let!(:contact_without_phone) do
        create(:contact, account: account, phone_number: nil)
      end

      before do
        contact_with_phone.update_labels([label.title])
        contact_without_phone.update_labels([label.title])
      end

      it 'expands labels to contacts with phone numbers only' do
        contacts = resolver.deliverable_contacts

        expect(contacts.size).to eq(1)
        expect(contacts.first).to include(
          'type' => 'Label',
          'id' => '+5511999990001',
          'name' => contact_with_phone.name
        )
      end

      it 'does not return raw label ids' do
        expect(resolver.deliverable_contacts.map { |c| c['id'] }).not_to include(label.id)
      end
    end

    context 'with spreadsheet audience' do
      let(:campaign) do
        create(:campaign,
               account: account,
               campaign_type: :one_off,
               audience: [{ 'type' => 'Contact', 'id' => '5511999990002', 'nome' => 'João' }])
      end

      it 'returns spreadsheet entries with phone' do
        expect(resolver.deliverable_contacts).to eq(campaign.audience)
      end
    end
  end

  describe '.normalize_job_contact' do
    it 'unwraps failed contact entries' do
      payload = {
        'contact' => { 'type' => 'Label', 'id' => '+5511999990001' },
        'error' => 'timeout'
      }

      expect(described_class.normalize_job_contact(payload)).to eq(payload['contact'])
    end

    it 'returns raw contact payloads unchanged' do
      payload = { 'type' => 'Label', 'id' => '+5511999990001' }

      expect(described_class.normalize_job_contact(payload)).to eq(payload)
    end
  end

  describe '.contact_phone_key' do
    it 'normalizes phone numbers for comparison' do
      expect(described_class.contact_phone_key({ 'id' => '+5511999990001' })).to eq('5511999990001')
      expect(described_class.contact_phone_key({ 'id' => '5511999990001' })).to eq('5511999990001')
    end
  end
end
