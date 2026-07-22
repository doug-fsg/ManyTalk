# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Activities', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/activities' do
    let!(:pending_activity) do
      create(
        :activity,
        account: account,
        user: admin,
        assignee: agent,
        status: 'pending',
        scheduled_at: 1.day.from_now
      )
    end
    let!(:completed_activity) do
      create(
        :activity,
        account: account,
        user: admin,
        assignee: agent,
        status: 'completed',
        completed_at: 1.hour.ago,
        scheduled_at: 2.days.ago
      )
    end

    it 'filters by user_id' do
      other_activity = create(:activity, account: account, user: agent, assignee: agent)

      get "/api/v1/accounts/#{account.id}/activities",
          params: { user_id: admin.id },
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.pluck('id')).to contain_exactly(pending_activity.id, completed_activity.id)
      expect(payload.pluck('id')).not_to include(other_activity.id)
    end

    it 'returns completed_at in payload' do
      get "/api/v1/accounts/#{account.id}/activities",
          headers: admin.create_new_auth_token,
          as: :json

      activity = response.parsed_body['payload'].find { |item| item['id'] == completed_activity.id }
      expect(activity['completed_at']).to be_present
    end

    it 'returns meta count based on filters' do
      get "/api/v1/accounts/#{account.id}/activities",
          params: { status: 'pending' },
          headers: admin.create_new_auth_token,
          as: :json

      expect(response.parsed_body['meta']['count']).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/activities/:id/complete' do
    let(:activity) do
      create(:activity, account: account, user: admin, assignee: agent, status: 'pending')
    end

    it 'sets completed_at when completing an activity' do
      post "/api/v1/accounts/#{account.id}/activities/#{activity.id}/complete",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(activity.reload.completed_at).to be_present
    end
  end
end
