# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForm do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'is valid with default attributes' do
      form = build(:account_form, account: account)
      expect(form).to be_valid
    end

    it 'requires a name' do
      form = build(:account_form, account: account, name: '')
      expect(form).not_to be_valid
    end

    it 'requires a unique slug per account' do
      create(:account_form, account: account, slug: 'my-form')
      form = build(:account_form, account: account, slug: 'my-form')
      expect(form).not_to be_valid
    end

    it 'allows same slug in different accounts' do
      other_account = create(:account)
      create(:account_form, account: account, slug: 'my-form')
      form = build(:account_form, account: other_account, slug: 'my-form')
      expect(form).to be_valid
    end

    it 'validates slug format — allows only lowercase alphanumeric and hyphens' do
      form = build(:account_form, account: account, slug: 'My Form!')
      expect(form).not_to be_valid
    end
  end

  describe 'slug normalization' do
    it 'parameterizes the name when slug is blank' do
      form = build(:account_form, account: account, name: 'My Contact Form', slug: '')
      form.valid?
      expect(form.slug).to eq('my-contact-form')
    end

    it 'preserves explicit slug' do
      form = build(:account_form, account: account, slug: 'explicit-slug')
      form.valid?
      expect(form.slug).to eq('explicit-slug')
    end
  end

  describe 'defaults' do
    it 'applies default definition on create' do
      form = create(:account_form, account: account, definition: {})
      expect(form.definition['fields']).to be_an(Array)
      expect(form.definition['fields'].length).to be > 0
    end

    it 'applies default branding on create' do
      form = create(:account_form, account: account)
      expect(form.branding['primary_color']).to be_present
    end
  end

  describe '#public_url' do
    it 'returns a URL containing account_id and slug' do
      form = create(:account_form, account: account, slug: 'test-form')
      expect(form.public_url).to include(account.id.to_s)
      expect(form.public_url).to include('test-form')
    end
  end

  describe '#submissions_count' do
    it 'returns the counter cache value' do
      form = create(:account_form, :published, account: account)
      create(:form_submission, account_form: form, account: account, contact: create(:contact, account: account))
      form.reload
      expect(form.submissions_count).to eq(1)
    end
  end

  describe 'status enum' do
    it 'has draft, published, paused statuses' do
      form = create(:account_form, account: account)
      expect(form).to be_draft
      form.published!
      expect(form).to be_published
      form.paused!
      expect(form).to be_paused
    end
  end

  describe 'definition validation' do
    it 'rejects definition with no fields' do
      form = create(:account_form, account: account)
      form.definition = { 'fields' => [] }
      expect(form).not_to be_valid
      expect(form.errors[:definition]).to be_present
    end

    it 'rejects definition with unknown native field' do
      form = create(:account_form, account: account)
      form.definition = {
        'fields' => [
          { 'key' => 'bad', 'type' => 'native', 'field' => 'unknown_field', 'label' => 'Bad' }
        ]
      }
      expect(form).not_to be_valid
    end

    it 'accepts valid definition with native fields' do
      form = create(:account_form, account: account)
      form.definition = {
        'fields' => [
          { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'label' => 'E-mail', 'required' => true }
        ]
      }
      expect(form).to be_valid
    end
  end
end
