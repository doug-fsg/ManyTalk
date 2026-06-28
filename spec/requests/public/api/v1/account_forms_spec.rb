# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public::Api::V1::AccountForms' do
  let(:account) { create(:account) }

  describe 'GET /public/api/v1/account_forms/:account_id/:slug' do
    context 'with published form' do
      let!(:form) { create(:account_form, :published, account: account) }

      it 'returns form data' do
        get "/public/api/v1/account_forms/#{account.id}/#{form.slug}"
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with paused form' do
      let!(:form) { create(:account_form, :paused, account: account) }

      it 'returns forbidden with message' do
        get "/public/api/v1/account_forms/#{account.id}/#{form.slug}"
        expect(response).to have_http_status(:forbidden)
        json = response.parsed_body
        expect(json['error']).to eq('form_paused')
        expect(json['message']).to be_present
      end
    end

    context 'with draft form' do
      let!(:form) { create(:account_form, account: account) }

      it 'returns not_found' do
        get "/public/api/v1/account_forms/#{account.id}/#{form.slug}"
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with nonexistent form' do
      it 'returns not_found' do
        get "/public/api/v1/account_forms/#{account.id}/nonexistent-slug"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /public/api/v1/account_forms/:account_id/:slug/submit' do
    let!(:form) { create(:account_form, :published, account: account) }
    let(:valid_params) { { name: 'Test User', email: 'test@example.com' } }

    it 'creates a submission' do
      expect do
        post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit",
             params: valid_params
      end.to change(FormSubmission, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'returns success response' do
      post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit",
           params: valid_params
      json = response.parsed_body
      expect(json['success']).to be true
    end

    context 'with honeypot filled' do
      it 'silently succeeds (bot trap)' do
        post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit",
             params: valid_params.merge(website_token: 'spam_value')
        expect(response).to have_http_status(:ok)
        expect(FormSubmission.count).to eq(0)
      end
    end

    context 'with invalid email' do
      it 'returns error with i18n message' do
        post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit",
             params: { name: 'Test', email: 'not-valid' }
        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['error']).to eq('invalid_email')
        expect(json['message']).to be_present
      end
    end

    context 'with paused form' do
      let!(:form) { create(:account_form, :paused, account: account) }

      it 'returns failure' do
        post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit",
             params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
