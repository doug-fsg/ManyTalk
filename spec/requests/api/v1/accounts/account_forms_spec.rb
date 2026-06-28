# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::AccountForms' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/account_forms' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/account_forms"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      it 'returns forbidden' do
        get "/api/v1/accounts/#{account.id}/account_forms",
            headers: { api_access_token: agent.access_token.token }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as admin' do
      before { create_list(:account_form, 3, account: account) }

      it 'returns list of forms' do
        get "/api/v1/accounts/#{account.id}/account_forms",
            headers: { api_access_token: admin.access_token.token }
        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['payload'].length).to eq(3)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/account_forms' do
    let(:valid_params) { { name: 'Test Form', slug: 'test-form' } }

    it 'creates a form when admin' do
      post "/api/v1/accounts/#{account.id}/account_forms",
           params: valid_params,
           headers: { api_access_token: admin.access_token.token }
      expect(response).to have_http_status(:success)
      expect(account.account_forms.count).to eq(1)
    end

    it 'rejects when agent' do
      post "/api/v1/accounts/#{account.id}/account_forms",
           params: valid_params,
           headers: { api_access_token: agent.access_token.token }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/account_forms/:id' do
    let(:form) { create(:account_form, account: account) }

    it 'returns form details' do
      get "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
          headers: { api_access_token: admin.access_token.token }
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(form.id)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/account_forms/:id' do
    let(:form) { create(:account_form, account: account) }

    it 'updates the form' do
      patch "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
            params: { name: 'Updated Name' },
            headers: { api_access_token: admin.access_token.token }
      expect(response).to have_http_status(:ok)
      expect(form.reload.name).to eq('Updated Name')
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/account_forms/:id' do
    let!(:form) { create(:account_form, account: account) }

    it 'deletes the form' do
      delete "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
             headers: { api_access_token: admin.access_token.token }
      expect(response).to have_http_status(:ok)
      expect(account.account_forms.count).to eq(0)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/account_forms/:id/update_status' do
    let(:form) { create(:account_form, account: account) }

    it 'publishes a draft form' do
      post "/api/v1/accounts/#{account.id}/account_forms/#{form.id}/update_status",
           params: { status: 'published' },
           headers: { api_access_token: admin.access_token.token }
      expect(response).to have_http_status(:ok)
      expect(form.reload).to be_published
    end

    it 'rejects invalid status' do
      post "/api/v1/accounts/#{account.id}/account_forms/#{form.id}/update_status",
           params: { status: 'invalid' },
           headers: { api_access_token: admin.access_token.token }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
