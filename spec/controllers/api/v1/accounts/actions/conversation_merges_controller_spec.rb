require 'rails_helper'

RSpec.describe 'Conversation Merge Action API', type: :request do
  let(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:contact) { create(:contact, account: account) }
  let!(:base_contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let!(:mergee_contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let!(:base_conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: base_contact_inbox)
  end
  let!(:mergee_conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: mergee_contact_inbox)
  end
  let(:merge_params) do
    {
      base_conversation_id: base_conversation.display_id,
      mergee_conversation_id: mergee_conversation.display_id
    }
  end

  shared_examples 'conversation merge endpoint' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post merge_path

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:merge_action) { instance_double(ConversationMergeAction, perform: base_conversation) }

      before do
        allow(ConversationMergeAction).to receive(:new).and_return(merge_action)
      end

      it 'merges two conversations by calling conversation merge action' do
        post merge_path,
             params: merge_params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body
        expect(json_response['id']).to eq(base_conversation.display_id)
        expected_params = {
          account: account,
          base_conversation: base_conversation,
          mergee_conversation: mergee_conversation
        }
        expect(ConversationMergeAction).to have_received(:new).with(expected_params)
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

    context 'when conversations belong to different inboxes' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let!(:other_inbox) { create(:inbox, account: account) }
      let!(:other_contact_inbox) { create(:contact_inbox, contact: contact, inbox: other_inbox) }
      let!(:mergee_conversation) do
        create(:conversation, account: account, inbox: other_inbox, contact: contact, contact_inbox: other_contact_inbox)
      end

      it 'returns unprocessable entity' do
        post merge_path,
             params: merge_params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to be_present
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/actions/conversation_merge' do
    let(:merge_path) { "/api/v1/accounts/#{account.id}/actions/conversation_merge" }

    include_examples 'conversation merge endpoint'
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/merge' do
    let(:merge_path) { "/api/v1/accounts/#{account.id}/conversations/merge" }

    include_examples 'conversation merge endpoint'
  end
end
