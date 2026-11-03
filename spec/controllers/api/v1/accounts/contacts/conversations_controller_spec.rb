require 'rails_helper'

RSpec.describe '/api/v1/accounts/{account.id}/contacts/:id/conversations', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox_1) { create(:inbox, account: account) }
  let(:inbox_2) { create(:inbox, account: account) }
  let(:contact_inbox_1) { create(:contact_inbox, contact: contact, inbox: inbox_1) }
  let(:contact_inbox_2) { create(:contact_inbox, contact: contact, inbox: inbox_2) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:unknown) { create(:user, account: account, role: nil) }

  before do
    create(:inbox_member, user: agent, inbox: inbox_1)
    2.times.each do
      create(:conversation, account: account, inbox: inbox_1, contact: contact, contact_inbox: contact_inbox_1)
      create(:conversation, account: account, inbox: inbox_2, contact: contact, contact_inbox: contact_inbox_2)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/contacts/:id/conversations' do
    context 'when unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is logged in' do
      context 'with user as administrator' do
        it 'returns conversations from all inboxes' do
          get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations", headers: admin.create_new_auth_token

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body

          expect(json_response['payload'].length).to eq 4
        end

        it 'serializes inbox, team and labels without missing associations' do
          team = create(:team, account: account)
          conversation = contact.conversations.first
          conversation.update!(team: team)
          conversation.update_labels('vip')

          get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations",
              headers: admin.create_new_auth_token

          expect(response).to have_http_status(:success)
          payload = response.parsed_body['payload'].find { |item| item['id'] == conversation.display_id }

          expect(payload['inbox_name']).to eq(conversation.inbox.name)
          expect(payload['labels']).to include('vip')
          expect(payload['meta']['team']['id']).to eq(team.id)
        end
      end

      context 'with user as agent' do
        it 'returns conversations from the inboxes which agent has access to' do
          get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations", headers: agent.create_new_auth_token

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body

          expect(json_response['payload'].length).to eq 2
        end
      end

      context 'with user as unknown role' do
        it 'returns conversations from no inboxes' do
          get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations", headers: unknown.create_new_auth_token

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body

          expect(json_response['payload'].length).to eq 0
        end
      end
    end
  end
end
