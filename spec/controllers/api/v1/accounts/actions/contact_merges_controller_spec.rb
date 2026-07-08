require 'rails_helper'

RSpec.describe 'Contact Merge Action API', type: :request do
  let(:account) { create(:account) }
  let!(:base_contact) { create(:contact, account: account) }
  let!(:mergee_contact) { create(:contact, account: account) }
  let(:merge_params) do
    { base_contact_id: base_contact.id, mergee_contact_id: mergee_contact.id }
  end

  shared_examples 'contact merge endpoint' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post merge_path

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:merge_action) { double }

      before do
        allow(ContactMergeAction).to receive(:new).and_return(merge_action)
        allow(merge_action).to receive(:perform).and_return(base_contact)
      end

      it 'merges two contacts by calling contact merge action' do
        post merge_path,
             params: merge_params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body
        expect(json_response['id']).to eq(base_contact.id)
        expected_params = { account: account, base_contact: base_contact, mergee_contact: mergee_contact }
        expect(ContactMergeAction).to have_received(:new).with(expected_params)
        expect(merge_action).to have_received(:perform)
      end

      it 'accepts api_access_token authentication' do
        post merge_path,
             params: merge_params,
             headers: { api_access_token: agent.access_token.token },
             as: :json

        expect(response).to have_http_status(:success)
      end

      it 'accepts Api-Access-Token authentication' do
        post merge_path,
             params: merge_params,
             headers: { 'Api-Access-Token' => agent.access_token.token },
             as: :json

        expect(response).to have_http_status(:success)
      end

      it 'accepts Authorization Bearer authentication' do
        post merge_path,
             params: merge_params,
             headers: { Authorization: "Bearer #{agent.access_token.token}" },
             as: :json

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/actions/contact_merge' do
    let(:merge_path) { "/api/v1/accounts/#{account.id}/actions/contact_merge" }

    include_examples 'contact merge endpoint'
  end

  describe 'POST /api/v1/accounts/{account.id}/contacts/merge' do
    let(:merge_path) { "/api/v1/accounts/#{account.id}/contacts/merge" }

    include_examples 'contact merge endpoint'
  end
end
