# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::WorkflowsController', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before { account.enable_features!('workflows') }

  let(:graph_payload) do
    {
      nodes: [
        {
          id: 'trigger_1',
          type: 'trigger',
          data: { event_name: 'conversation_created', conditions: [] }
        }
      ],
      edges: [],
      settings: {
        cancel_on_contact_reply: true,
        cancel_on_conversation_resolved: true
      }
    }
  end

  describe 'POST /api/v1/accounts/:account_id/workflows' do
    it 'creates workflow with graph payload' do
      expect do
        post "/api/v1/accounts/#{account.id}/workflows",
             params: {
               name: 'Novo fluxo',
               description: 'Teste',
               active: false,
               graph: graph_payload
             },
             headers: agent.create_new_auth_token,
             as: :json
      end.to change(Workflow, :count).by(1)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['graph']['nodes']).to be_an(Array)
      expect(body['graph']['nodes'].first['type']).to eq('trigger')
    end

    it 'returns 422 when graph is missing' do
      post "/api/v1/accounts/#{account.id}/workflows",
           params: { name: 'Sem grafo', active: false },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      errors = response.parsed_body['error']
      expect(errors).to include('Graph must include nodes array')
    end
  end
end
