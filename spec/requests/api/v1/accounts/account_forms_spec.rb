# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::AccountForms' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin_headers) { admin.create_new_auth_token }
  let(:agent_headers) { agent.create_new_auth_token }

  before { account.enable_features!('workflows') }

  describe 'GET /api/v1/accounts/:account_id/account_forms' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/account_forms"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      before { create_list(:account_form, 2, account: account) }

      it 'returns list of forms' do
        get "/api/v1/accounts/#{account.id}/account_forms",
            headers: agent_headers,
            as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['payload'].length).to eq(2)
      end

      it 'includes linked_workflows and linkage_state per form' do
        get "/api/v1/accounts/#{account.id}/account_forms",
            headers: agent_headers,
            as: :json
        payload = response.parsed_body['payload']
        expect(payload.first).to include('linked_workflows', 'linkage_state')
        expect(payload.first['linkage_state']).to eq('contact_only')
        expect(payload.first['linked_workflows']).to eq([])
      end
    end

    context 'when workflows feature is disabled' do
      before { account.disable_features!('workflows') }

      it 'returns unauthorized for agent' do
        get "/api/v1/accounts/#{account.id}/account_forms",
            headers: agent_headers,
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end


    context 'when authenticated as admin' do
      before { create_list(:account_form, 3, account: account) }

      it 'returns list of forms' do
        get "/api/v1/accounts/#{account.id}/account_forms",
            headers: admin_headers,
            as: :json
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
           headers: admin_headers,
           as: :json
      expect(response).to have_http_status(:success)
      expect(account.account_forms.count).to eq(1)
    end

    it 'creates a form when agent' do
      post "/api/v1/accounts/#{account.id}/account_forms",
           params: valid_params,
           headers: agent_headers,
           as: :json
      expect(response).to have_http_status(:success)
      expect(account.account_forms.count).to eq(1)
    end

  end

  describe 'GET /api/v1/accounts/:account_id/account_forms/:id' do
    let(:form) { create(:account_form, account: account) }

    it 'returns form details for admin' do
      get "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
          headers: admin_headers,
          as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(form.id)
      expect(json).to include('linked_workflows', 'linkage_state')
      expect(json['linkage_state']).to eq('contact_only')
    end

    it 'returns form details for agent' do
      get "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
          headers: agent_headers,
          as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(form.id)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/account_forms/:id' do
    let(:form) { create(:account_form, account: account) }

    it 'updates the form as admin' do
      patch "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
            params: { name: 'Updated Name' },
            headers: admin_headers,
            as: :json
      expect(response).to have_http_status(:ok)
      expect(form.reload.name).to eq('Updated Name')
    end

    it 'updates the form as agent' do
      patch "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
            params: { name: 'Agent Updated' },
            headers: agent_headers,
            as: :json
      expect(response).to have_http_status(:ok)
      expect(form.reload.name).to eq('Agent Updated')
    end

    it 'persists appearance branding fields' do
      patch "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
            params: {
              branding: {
                background_color: '#0b1220',
                text_color: '#f8fafc',
                logo_alignment: 'left',
                logo_expand: true
              }
            },
            headers: admin_headers,
            as: :json
      expect(response).to have_http_status(:ok)
      form.reload
      expect(form.branding['background_color']).to eq('#0b1220')
      expect(form.branding['text_color']).to eq('#f8fafc')
      expect(form.branding['logo_alignment']).to eq('left')
      expect(form.branding['logo_expand']).to eq(true)
    end

    it 'coerces invalid background_color to default' do
      patch "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
            params: { branding: { background_color: 'red;}' } },
            headers: admin_headers,
            as: :json
      expect(response).to have_http_status(:ok)
      expect(form.reload.branding['background_color']).to eq('#ffffff')
    end

    it 'preserves logo_url on partial branding update' do
      form.update!(
        branding: form.branding.merge('logo_url' => 'https://cdn.example/logo.png')
      )
      patch "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
            params: { branding: { text_color: '#111111' } },
            headers: admin_headers,
            as: :json
      expect(response).to have_http_status(:ok)
      form.reload
      expect(form.branding['logo_url']).to eq('https://cdn.example/logo.png')
      expect(form.branding['text_color']).to eq('#111111')
    end

    it 'rejects save when no field is required' do
      patch "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
            params: {
              definition: {
                fields: [
                  { key: 'name', type: 'native', field: 'name', required: false },
                  { key: 'email', type: 'native', field: 'email', required: false }
                ]
              }
            },
            headers: admin_headers,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq(
        I18n.t('account_forms.errors.no_required_fields')
      )
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/account_forms/:id' do
    let!(:form) { create(:account_form, account: account) }

    it 'deletes the form as admin' do
      delete "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
             headers: admin_headers,
             as: :json
      expect(response).to have_http_status(:ok)
      expect(account.account_forms.count).to eq(0)
    end

    it 'deletes the form with submissions as admin' do
      FormSubmission.create!(
        account: account,
        account_form: form,
        payload: { 'email' => 'user@example.com' }
      )

      delete "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
             headers: admin_headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(account.account_forms.count).to eq(0)
      expect(FormSubmission.count).to eq(0)
    end

    it 'deletes the form as agent' do
      delete "/api/v1/accounts/#{account.id}/account_forms/#{form.id}",
             headers: agent_headers,
             as: :json
      expect(response).to have_http_status(:ok)
      expect(account.account_forms.count).to eq(0)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/account_forms/:id/update_status' do
    let(:form) { create(:account_form, account: account) }

    it 'publishes a draft form' do
      post "/api/v1/accounts/#{account.id}/account_forms/#{form.id}/update_status",
           params: { status: 'published' },
           headers: admin_headers,
           as: :json
      expect(response).to have_http_status(:ok)
      expect(form.reload).to be_published
    end

    it 'publishes a draft form with string required flag' do
      form.update!(definition: {
                     'fields' => [
                       { 'key' => 'name', 'type' => 'native', 'field' => 'name', 'required' => 'true' }
                     ]
                   })

      post "/api/v1/accounts/#{account.id}/account_forms/#{form.id}/update_status",
           params: { status: 'published' },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(form.reload).to be_published
    end

    it 'rejects publishing when no field is required' do
      form.update!(definition: {
                     'fields' => [
                       { 'key' => 'name', 'type' => 'native', 'field' => 'name', 'required' => false },
                       { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'required' => false }
                     ]
                   })

      post "/api/v1/accounts/#{account.id}/account_forms/#{form.id}/update_status",
           params: { status: 'published' },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq(
        I18n.t('account_forms.errors.no_required_fields')
      )
      expect(form.reload).to be_draft
    end

    it 'rejects invalid status' do
      post "/api/v1/accounts/#{account.id}/account_forms/#{form.id}/update_status",
           params: { status: 'invalid' },
           headers: admin_headers,
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'pauses a published form' do
      form.update!(status: :published)

      post "/api/v1/accounts/#{account.id}/account_forms/#{form.id}/update_status",
           params: { status: 'paused' },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(form.reload).to be_paused
    end
  end
end
