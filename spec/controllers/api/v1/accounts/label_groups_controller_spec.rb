# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Label Groups API', type: :request do
  let!(:account) { create(:account) }
  let!(:label_group) { create(:label_group, account: account, name: 'Status') }

  describe 'GET /api/v1/accounts/{account.id}/label_groups' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/label_groups"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the label groups in account' do
        get "/api/v1/accounts/#{account.id}/label_groups",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].first['name']).to eq('Status')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/label_groups' do
    let(:valid_params) { { label_group: { name: 'Funnel' } } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        expect do
          post "/api/v1/accounts/#{account.id}/label_groups", params: valid_params
        end.not_to change(LabelGroup, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated administrator' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'creates the label group' do
        expect do
          post "/api/v1/accounts/#{account.id}/label_groups",
               headers: admin.create_new_auth_token,
               params: valid_params,
               as: :json
        end.to change(LabelGroup, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['name']).to eq('Funnel')
      end
    end

    context 'when it is an agent' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/label_groups",
             headers: agent.create_new_auth_token,
             params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/label_groups/:id' do
    let(:admin) { create(:user, account: account, role: :administrator) }

    it 'updates the label group' do
      patch "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
            headers: admin.create_new_auth_token,
            params: { label_group: { name: 'Priority' } },
            as: :json

      expect(response).to have_http_status(:success)
      expect(label_group.reload.name).to eq('Priority')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/label_groups/:id' do
    let(:admin) { create(:user, account: account, role: :administrator) }

    it 'deletes the label group and nullifies labels' do
      label = create(:label, account: account, label_group: label_group)

      expect do
        delete "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
               headers: admin.create_new_auth_token
      end.to change(LabelGroup, :count).by(-1)

      expect(response).to have_http_status(:success)
      expect(label.reload.label_group_id).to be_nil
    end
  end
end
