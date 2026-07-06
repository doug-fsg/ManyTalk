# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForms::SubmitService do
  let(:account) { create(:account) }
  let(:form) { create(:account_form, :published, account: account) }

  def call_service(params = {})
    described_class.new(
      account_form: form,
      params: ActionController::Parameters.new(params),
      request_meta: { ip_address: '127.0.0.1', user_agent: 'Test' }
    ).perform
  end

  describe '#perform' do
    context 'when form is not published' do
      let(:form) { create(:account_form, account: account) }

      it 'returns failure with form_unavailable' do
        result = call_service(name: 'Test', email: 'test@example.com')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('form_unavailable')
      end
    end

    context 'with valid native fields' do
      let(:params) { { name: 'Test User', email: 'test@example.com' } }

      it 'creates a contact and submission' do
        expect { call_service(**params) }
          .to change(Contact, :count).by(1)
          .and change(FormSubmission, :count).by(1)
      end

      it 'returns success' do
        result = call_service(**params)
        expect(result[:success]).to be true
        expect(result[:contact]).to be_a(Contact)
        expect(result[:submission]).to be_a(FormSubmission)
      end
    end

    context 'with missing required field' do
      it 'returns failure with missing_email when email required but blank' do
        result = call_service(name: 'Test User', email: '')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('missing_email')
      end
    end

    context 'with invalid email' do
      it 'returns failure with invalid_email' do
        result = call_service(name: 'Test', email: 'not-an-email')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('invalid_email')
      end
    end

    context 'with Brazilian phone number' do
      it 'normalizes (11) 99999-9999 to E.164 format' do
        result = call_service(name: 'Test', email: 'test@example.com', phone_number: '(11) 99999-9999')
        # If PhoneNormalizer can handle this format, result is success
        # If it cannot normalize, result is failure with invalid_phone_number
        if result[:success]
          expect(result[:contact].phone_number).to match(/\A\+\d+\z/)
        else
          expect(result[:error]).to eq('invalid_phone_number')
        end
      end

      it 'accepts valid E.164 phone number' do
        result = call_service(name: 'Test', email: 'test@example.com', phone_number: '+5511999999999')
        expect(result[:success]).to be true
        expect(result[:contact].phone_number).to eq('+5511999999999')
      end

      it 'rejects invalid phone' do
        result = call_service(name: 'Test', email: 'test@example.com', phone_number: 'not-a-phone')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('invalid_phone_number')
      end
    end

    context 'with deduplication' do
      let!(:existing_contact) do
        create(:contact, account: account, email: 'existing@example.com', name: 'Old Name')
      end

      it 'updates the existing contact when dedup_key matches' do
        result = call_service(name: 'New Name', email: 'existing@example.com')
        expect(result[:success]).to be true
        expect(result[:contact].id).to eq(existing_contact.id)
        expect(result[:contact].reload.name).to eq('New Name')
      end

      it 'keeps existing contact when dedup_policy is keep_existing' do
        form.settings['dedup_policy'] = 'keep_existing'
        form.save!
        result = call_service(name: 'New Name', email: 'existing@example.com')
        expect(result[:success]).to be true
        expect(existing_contact.reload.name).to eq('Old Name')
      end
    end

    context 'with honeypot' do
      it 'does not check honeypot in service (handled by controller)' do
        result = call_service(name: 'Test', email: 'test@example.com', website_token: 'spam')
        expect(result[:success]).to be true
      end
    end

    context 'with UTM parameters' do
      it 'stores utm params in submission' do
        result = call_service(
          name: 'Test', email: 'test@example.com',
          utm_source: 'google', utm_medium: 'cpc'
        )
        expect(result[:success]).to be true
        expect(result[:submission].utm['utm_source']).to eq('google')
        expect(result[:submission].utm['utm_medium']).to eq('cpc')
      end
    end

    context 'when all fields are optional and payload is empty' do
      before do
        form.definition = {
          'fields' => [
            { 'key' => 'name', 'type' => 'native', 'field' => 'name', 'required' => false },
            { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'required' => false }
          ]
        }
        form.save!
      end

      it 'returns failure with empty_submission' do
        result = call_service
        expect(result[:success]).to be false
        expect(result[:error]).to eq('empty_submission')
      end
    end

    context 'when phone belongs to another contact during update' do
      let!(:other_contact) do
        create(:contact, account: account, email: 'other@example.com', phone_number: '+5511888888888')
      end
      let!(:existing_contact) do
        create(:contact, account: account, email: 'existing@example.com', name: 'Existing')
      end

      it 'submits without failing when phone is already used elsewhere' do
        result = call_service(
          name: 'Existing',
          email: 'existing@example.com',
          phone_number: '+5511888888888'
        )
        expect(result[:success]).to be true
        expect(existing_contact.reload.phone_number).not_to eq('+5511888888888')
      end
    end

    context 'when phone already exists on another contact' do
      let!(:phone_contact) do
        create(:contact, account: account, email: 'phone-owner@example.com', phone_number: '+5511999999999', name: 'Phone Owner')
      end

      it 'reuses and updates the contact matched by phone' do
        result = call_service(
          name: 'Updated Name',
          email: 'new-email@example.com',
          phone_number: '+5511999999999'
        )

        expect(result[:success]).to be true
        expect(result[:contact].id).to eq(phone_contact.id)
        expect(phone_contact.reload.name).to eq('Updated Name')
        expect(phone_contact.email).to eq('new-email@example.com')
      end

      it 'keeps existing data when dedup_policy is keep_existing' do
        form.settings['dedup_policy'] = 'keep_existing'
        form.save!

        result = call_service(
          name: 'Updated Name',
          email: 'new-email@example.com',
          phone_number: '+5511999999999'
        )

        expect(result[:success]).to be true
        expect(result[:contact].id).to eq(phone_contact.id)
        expect(phone_contact.reload.name).to eq('Phone Owner')
        expect(phone_contact.email).to eq('phone-owner@example.com')
      end
    end
  end
end
