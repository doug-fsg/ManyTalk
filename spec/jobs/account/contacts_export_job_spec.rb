# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account::ContactsExportJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, email: 'account-user-test@test.com', role: :administrator) }
  let(:label) { create(:label, title: 'spec-billing', account: account) }

  def parse_export_csv(account)
    raw = account.contacts_export.download.force_encoding('UTF-8')
    CSV.parse(raw.delete_prefix(Contacts::ExportService::UTF8_BOM), headers: true)
  end

  let(:email_filter) do
    {
      attribute_key: 'email',
      filter_operator: 'contains',
      values: 'looped',
      query_operator: 'and',
      attribute_model: 'standard',
      custom_attribute_type: ''
    }
  end

  let(:city_filter) do
    {
      attribute_key: 'country_code',
      filter_operator: 'equal_to',
      values: ['India'],
      query_operator: 'and',
      attribute_model: 'standard',
      custom_attribute_type: ''
    }
  end

  let(:single_filter) do
    {
      payload: [email_filter.merge(query_operator: nil)]
    }
  end

  let(:multiple_filters) do
    {
      payload: [city_filter, email_filter.merge(query_operator: nil)]
    }
  end

  it 'enqueues the job' do
    expect do
      described_class.perform_later(account.id, user.id, [], {})
    end.to have_enqueued_job(described_class).on_queue('low')
  end

  context 'when export_contacts' do
    before do
      create(:contact, account: account, phone_number: '+910808080818', email: 'test1@text.example')
      4.times do |i|
        create(:contact, account: account, email: "looped-#{i + 3}@text.example.com")
      end
      4.times do |i|
        create(:contact, account: account, additional_attributes: { country_code: 'India' }, email: "looped-#{i + 10}@text.example.com")
      end
      create(:contact, account: account, phone_number: '+910808080808', email: 'test2@text.example')
    end

    it 'generates CSV file and emails only the requesting user' do
      other_admin = create(:user, account: account, role: :administrator, email: 'other-admin@test.com')
      mailer = double
      mail_message = double(deliver_later: true)
      allow(AdministratorNotifications::ChannelNotificationsMailer).to receive(:with).with(account: account).and_return(mailer)
      allow(mailer).to receive(:contact_export_complete).and_return(mail_message)

      described_class.perform_now(account.id, user.id, [], {})

      file_url = Rails.application.routes.url_helpers.rails_blob_url(account.contacts_export)

      expect(account.contacts_export).to be_present
      expect(file_url).to be_present
      expect(mailer).to have_received(:contact_export_complete).with(file_url, user.email)
      expect(mailer).not_to have_received(:contact_export_complete).with(anything, other_admin.email)
    end

    it 'generates valid data export file' do
      described_class.perform_now(account.id, user.id, %w[id name email phone_number column_not_present], {})

      csv_data = parse_export_csv(account)
      emails = csv_data.pluck('email')
      phone_numbers = csv_data.pluck('phone_number')

      expect(csv_data.length).to eq(account.contacts.count)

      expect(emails).to include('test1@text.example', 'test2@text.example')
      expect(phone_numbers).to include('+910808080818', '+910808080808')
    end

    it 'returns all resolved contacts as results when filter is not provided' do
      create(:contact, account: account, email: nil, phone_number: nil)
      described_class.perform_now(account.id, user.id, %w[id name email column_not_present], {})
      csv_data = parse_export_csv(account)
      expect(csv_data.length).to eq(account.contacts.resolved_contacts.count)
    end

    it 'returns resolved contacts filtered if labels are provided' do
      Contact.last.add_labels(['spec-billing'])
      contact = create(:contact, account: account, email: nil, phone_number: nil)
      contact.add_labels(['spec-billing'])
      described_class.perform_now(account.id, user.id, [], { payload: nil, label: 'spec-billing' })
      csv_data = parse_export_csv(account)
      expect(csv_data.length).to eq(1)
    end

    it 'returns filtered data which includes unresolved contacts when filter is provided' do
      create(:contact, account: account, email: nil, phone_number: nil, additional_attributes: { country_code: 'India' })
      described_class.perform_now(account.id, user.id, [], { payload: [city_filter.merge(query_operator: nil)] }.with_indifferent_access)
      csv_data = parse_export_csv(account)
      expect(csv_data.length).to eq(5)
    end

    it 'returns filtered data when multiple filters are provided' do
      described_class.perform_now(account.id, user.id, [], multiple_filters.with_indifferent_access)
      csv_data = parse_export_csv(account)
      expect(csv_data.length).to eq(4)
    end

    it 'returns filtered data when a single filter is provided' do
      described_class.perform_now(account.id, user.id, [], single_filter.with_indifferent_access)
      csv_data = parse_export_csv(account)
      expect(csv_data.length).to eq(8)
    end

    it 'filters by account_form_id' do
      form = create(:account_form, :published, account: account)
      contact = create(:contact, :with_email, account: account)
      FormSubmission.create!(
        account: account,
        account_form: form,
        contact: contact,
        payload: { 'email' => contact.email }
      )

      described_class.perform_now(account.id, user.id, [], { account_form_id: form.id })
      csv_data = parse_export_csv(account)
      expect(csv_data.length).to eq(1)
      expect(csv_data.first['email']).to eq(contact.email)
    end
  end
end
