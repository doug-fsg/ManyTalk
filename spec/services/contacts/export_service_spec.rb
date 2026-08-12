# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contacts::ExportService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:account_user) { account.account_users.find_by!(user_id: admin.id) }

  before { Current.account = account }

  after { Current.reset }

  describe '#export_mode' do
    it 'returns direct when count is within limit' do
      create(:contact, :with_email, account: account)
      service = described_class.new(account: account, account_user: account_user, params: {})

      expect(service.export_mode).to eq('direct')
      expect(service.direct_download?).to be(true)
    end

    it 'returns email when count exceeds limit' do
      stub_const('Contacts::ExportService::DIRECT_DOWNLOAD_LIMIT', 1)
      create_list(:contact, 2, :with_email, account: account)
      service = described_class.new(account: account, account_user: account_user, params: {})

      expect(service.export_mode).to eq('email')
      expect(service.direct_download?).to be(false)
    end
  end

  describe '#to_csv' do
    it 'prefixes csv with utf-8 bom' do
      create(:contact, :with_email, account: account, name: 'Lead')
      service = described_class.new(account: account, account_user: account_user, params: {})

      expect(service.to_csv.start_with?(described_class::UTF8_BOM)).to be(true)
    end

    it 'filters contacts by account_form_id' do
      form = create(:account_form, :published, account: account)
      contact_with_submission = create(:contact, :with_email, account: account, name: 'Form Lead')
      other_contact = create(:contact, :with_email, account: account, name: 'Other')
      FormSubmission.create!(
        account: account,
        account_form: form,
        contact: contact_with_submission,
        payload: { 'name' => 'Form Lead' }
      )

      service = described_class.new(
        account: account,
        account_user: account_user,
        params: { account_form_id: form.id }
      )
      csv = service.to_csv

      expect(csv).to include(contact_with_submission.email)
      expect(csv).not_to include(other_contact.email)
      expect(service.count).to eq(1)
    end

    it 'includes contact custom attributes as columns' do
      create(
        :custom_attribute_definition,
        account: account,
        attribute_model: :contact_attribute,
        attribute_key: 'cpf',
        attribute_display_name: 'CPF',
        attribute_display_type: :text
      )
      create(
        :custom_attribute_definition,
        account: account,
        attribute_model: :contact_attribute,
        attribute_key: 'vip',
        attribute_display_name: 'VIP',
        attribute_display_type: :checkbox
      )
      create(
        :custom_attribute_definition,
        :kanban,
        account: account,
        attribute_key: 'pipeline_stage',
        attribute_display_name: 'Pipeline'
      )
      create(
        :contact,
        :with_email,
        account: account,
        name: 'Attr Lead',
        custom_attributes: { 'cpf' => '123.456.789-00', 'vip' => true, 'pipeline_stage' => 'Estágio 1' }
      )

      service = described_class.new(account: account, account_user: account_user, params: {})
      rows = CSV.parse(service.to_csv.delete_prefix(described_class::UTF8_BOM), headers: true)
      row = rows.find { |r| r['name'] == 'Attr Lead' }

      expect(rows.headers).to include('CPF', 'VIP')
      expect(rows.headers).not_to include('Pipeline')
      expect(row['CPF']).to eq('123.456.789-00')
      expect(row['VIP']).to eq('true')
    end
  end
end
