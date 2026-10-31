# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account AI usage API', type: :request do
  let(:account) { create(:account, ai_credit_limit: 100, ai_credits_used: 100) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def auth_headers_for(user)
    user.create_new_auth_token.except('Authorization')
  end

  def json_body
    response.parsed_body
  end

  def secret_keys_in(payload)
    payload = payload.is_a?(Array) ? payload : [payload]
    payload.flat_map { |item| item.is_a?(Hash) ? item.keys : [] }.grep(/model|provider|api_key|openai/i)
  end

  describe 'GET /api/v1/accounts/{account.id}/ai_usage' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_usage"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_usage",
            headers: auth_headers_for(agent),
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated administrator' do
      it 'returns limit, used, remaining and paused without LLM secrets' do
        get "/api/v1/accounts/#{account.id}/ai_usage",
            headers: auth_headers_for(administrator),
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_body['limit']).to eq(100)
        expect(json_body['used']).to eq(100)
        expect(json_body['remaining']).to eq(0)
        expect(json_body['paused']).to be(true)
        expect(secret_keys_in(json_body)).to be_empty
      end
    end
  end
end
