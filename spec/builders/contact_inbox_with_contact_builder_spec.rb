require 'rails_helper'

describe ContactInboxWithContactBuilder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, email: 'xyc@example.com', phone_number: '+23423424123', account: account, identifier: '123') }
  let(:existing_contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

  describe '#perform' do
    it 'doesnot create contact if it already exist with source id' do
      contact_inbox = described_class.new(
        source_id: existing_contact_inbox.source_id,
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'creates contact if contact doesnot exist with source id' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: 'testemail@example.com',
          custom_attributes: { test: 'test' }
        }
      ).perform

      expect(contact_inbox.contact.id).not_to eq(contact.id)
      expect(contact_inbox.contact.name).to eq('Contact')
      expect(contact_inbox.contact.custom_attributes).to eq({ 'test' => 'test' })
      expect(contact_inbox.inbox_id).to eq(inbox.id)
    end

    it 'doesnot create contact if it already exist with identifier' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          identifier: contact.identifier,
          phone_number: contact.phone_number,
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact if it already exist with email' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: contact.email
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact when an uppercase email is passed for an already existing contact email' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: contact.email.upcase
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact if it already exist with phone number' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: contact.phone_number,
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    context 'with Brazilian WhatsApp phone variants' do
      before do
        stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
      end

      let!(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
      let(:whatsapp_inbox) { whatsapp_channel.inbox }
      let(:with_nine) { '5553999067484' }
      let(:without_nine) { '555399067484' }

      it 'reuses contact when phone_number is the BR variant without the ninth digit' do
        existing = create(:contact, account: account, phone_number: "+#{with_nine}", name: 'Existing BR')

        contact_inbox = described_class.new(
          source_id: without_nine,
          inbox: whatsapp_inbox,
          contact_attributes: {
            name: 'Incoming',
            phone_number: "+#{without_nine}"
          }
        ).perform

        expect(contact_inbox.contact.id).to eq(existing.id)
        expect(whatsapp_inbox.contact_inboxes.where(contact_id: existing.id).count).to eq(1)
      end

      it 'reuses contact_inbox when source_id is the BR variant without the ninth digit' do
        existing = create(:contact, account: account, phone_number: "+#{with_nine}")
        existing_ci = create(:contact_inbox, inbox: whatsapp_inbox, contact: existing, source_id: with_nine)

        contact_inbox = described_class.new(
          source_id: without_nine,
          inbox: whatsapp_inbox,
          contact_attributes: {
            name: 'Incoming',
            phone_number: "+#{without_nine}"
          }
        ).perform

        expect(contact_inbox.id).to eq(existing_ci.id)
        expect(whatsapp_inbox.contact_inboxes.count).to eq(1)
      end

      it 'reuses contact without contact_inbox and creates one CI with incoming waid' do
        existing = create(:contact, account: account, phone_number: "+#{with_nine}", name: 'CRM Contact')

        expect do
          described_class.new(
            source_id: without_nine,
            inbox: whatsapp_inbox,
            contact_attributes: {
              name: 'Incoming',
              phone_number: "+#{without_nine}"
            }
          ).perform
        end.not_to change(Contact, :count)

        expect(existing.contact_inboxes.find_by(inbox: whatsapp_inbox).source_id).to eq(without_nine)
        expect(whatsapp_inbox.contact_inboxes.count).to eq(1)
      end

      it 'reuses existing contact_inbox for the contact when source_id differs by ninth digit' do
        existing = create(:contact, account: account, phone_number: "+#{with_nine}")
        existing_ci = create(:contact_inbox, inbox: whatsapp_inbox, contact: existing, source_id: with_nine)

        # Skip source_id match path by using a source that resolves, then ensure guard
        # still binds to the same contact+inbox CI when phone matches via variant.
        contact_inbox = described_class.new(
          source_id: without_nine,
          inbox: whatsapp_inbox,
          contact_attributes: {
            name: 'Incoming',
            phone_number: "+#{without_nine}"
          }
        ).perform

        expect(contact_inbox.id).to eq(existing_ci.id)
        expect(ContactInbox.where(inbox: whatsapp_inbox, contact: existing).count).to eq(1)
      end
    end
  end
end
