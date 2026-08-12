# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForms::CsvExportService do
  let(:account) { create(:account, custom_attributes: { 'timezone' => 'America/Sao_Paulo' }) }
  let(:account_form) { create(:account_form, account: account) }
  let(:submission) do
    FormSubmission.create!(
      account: account,
      account_form: account_form,
      payload: { 'email' => 'user@example.com', 'name' => 'Test User' },
      utm: { 'utm_source' => 'google' },
      created_at: Time.utc(2026, 8, 11, 15, 30, 0)
    )
  end

  subject(:csv_data) { described_class.new(account_form, [submission]).call }

  it 'prefixes the csv with a utf-8 bom for excel compatibility' do
    expect(csv_data.start_with?(described_class::UTF8_BOM)).to be(true)
  end

  it 'exports submission data with field labels' do
    expect(csv_data).to include('user@example.com')
    expect(csv_data).to include('Test User')
    expect(csv_data).to include('google')
  end

  it 'formats created_at using the account timezone' do
    expect(csv_data).to include('2026-08-11 12:30:00')
  end
end
