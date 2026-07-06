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

      it 'includes appearance branding defaults' do
        form.update_column(:branding, { 'primary_color' => '#112233' }) # rubocop:disable Rails/SkipsModelValidations
        get "/public/api/v1/account_forms/#{account.id}/#{form.slug}"
        expect(response).to have_http_status(:ok)
        branding = response.parsed_body['branding']
        expect(branding['primary_color']).to eq('#112233')
        expect(branding['background_color']).to eq('#ffffff')
        expect(branding['page_background_color']).to eq('#f8fafc')
        expect(branding['text_color']).to eq('#0f172a')
        expect(branding['logo_alignment']).to eq('center')
        expect(branding['logo_expand']).to eq(false)
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
        expect do
          post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit",
               params: valid_params.merge(website_token: 'spam_value')
        end.not_to change(FormSubmission, :count)
        expect(response).to have_http_status(:ok)
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

    context 'with empty payload and optional fields' do
      let!(:form) do
        form = create(:account_form, account: account, definition: {
                        'fields' => [
                          { 'key' => 'name', 'type' => 'native', 'field' => 'name', 'required' => false },
                          { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'required' => false }
                        ]
                      })
        # Legacy published forms may exist without required fields; bypass publish validation for this fixture.
        form.update_column(:status, AccountForm.statuses[:published]) # rubocop:disable Rails/SkipsModelValidations
        form
      end

      it 'returns empty_submission error' do
        post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit", params: {}
        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['error']).to eq('empty_submission')
        expect(json['message']).to be_present
      end
    end

    context 'with JSON body' do
      it 'creates a submission when Content-Type is application/json' do
        post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit",
             params: { name: 'JSON User', email: 'json-user@example.com' }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['success']).to be true
      end
    end

    context 'with paused form' do
      let!(:form) { create(:account_form, :paused, account: account) }

      it 'returns forbidden when paused' do
        post "/public/api/v1/account_forms/#{account.id}/#{form.slug}/submit",
             params: valid_params
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('form_paused')
      end
    end
  end
end
