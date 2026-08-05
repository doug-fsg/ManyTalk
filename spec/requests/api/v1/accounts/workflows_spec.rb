# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Workflows' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:agent_headers) { agent.create_new_auth_token.except('Authorization') }

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

  describe 'GET /api/v1/accounts/:account_id/workflows/templates' do
    it 'lists available templates' do
      get "/api/v1/accounts/#{account.id}/workflows/templates",
          headers: agent_headers,
          as: :json

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.length).to eq(4)
      expect(payload.first).to include('key', 'name', 'description', 'category', 'trigger_event', 'step_count')
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/workflows/templates", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/workflows/from_template' do
    it 'creates workflow from template' do
      expect do
        post "/api/v1/accounts/#{account.id}/workflows/from_template",
             params: { template_key: 'follow_up_basic' },
             headers: agent_headers,
             as: :json
      end.to change(Workflow, :count).by(1)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['active']).to be false
      expect(body['graph']['nodes']).to be_an(Array)
    end

    it 'returns 422 for invalid template key' do
      post "/api/v1/accounts/#{account.id}/workflows/from_template",
           params: { template_key: 'invalid' },
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/workflows/validate' do
    it 'returns valid for minimal graph' do
      post "/api/v1/accounts/#{account.id}/workflows/validate",
           params: { graph: graph_payload },
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['valid']).to be true
      expect(body['errors']).to eq([])
    end

    it 'returns structured errors for invalid graph' do
      post "/api/v1/accounts/#{account.id}/workflows/validate",
           params: { graph: { nodes: [], edges: [] } },
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['valid']).to be false
      expect(body['errors'].first).to include('message')
    end

    it 'accepts form_submitted trigger with inbox and published forms' do
      inbox = create(:inbox, account: account)
      published_form = create(:account_form, :published, account: account)
      form_graph = {
        nodes: [
          {
            id: 'trigger_1',
            type: 'trigger',
            data: {
              event_name: 'form_submitted',
              inbox_id: inbox.id.to_s,
              conditions: [
                {
                  attribute_key: 'account_form_id',
                  filter_operator: 'equal_to',
                  values: [published_form.id.to_s]
                }
              ]
            }
          },
          {
            id: 'action_1',
            type: 'action',
            data: { action_name: 'add_label', action_params: ['lead'] }
          }
        ],
        edges: [{ id: 'e1', source: 'trigger_1', target: 'action_1' }],
        settings: {}
      }

      post "/api/v1/accounts/#{account.id}/workflows/validate",
           params: { graph: form_graph },
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['valid']).to be true
      expect(body['errors']).to eq([])
    end
  end

  describe 'GET /api/v1/accounts/:account_id/workflows' do
    it 'includes metrics in payload' do
      create(:workflow, account: account, name: 'Fluxo com métricas')

      get "/api/v1/accounts/#{account.id}/workflows",
          headers: agent_headers,
          as: :json

      expect(response).to have_http_status(:success)
      workflow = response.parsed_body['payload'].first
      expect(workflow['metrics']).to include('active_count', 'reply_rate_30d', 'completion_rate_30d')
    end
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
             headers: agent_headers,
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
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      errors = response.parsed_body['error']
      expect(errors).to include('Graph must include nodes array')
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/workflows/:id' do
    let(:workflow) { create(:workflow, account: account, active: true) }
    let(:conversation) { create(:conversation, account: account) }

    it 'destroys workflow with enrollments' do
      enrollment = create(:workflow_enrollment, workflow: workflow, conversation: conversation, status: 'active')
      create(:workflow_step_execution, workflow_enrollment: enrollment)

      expect do
        delete "/api/v1/accounts/#{account.id}/workflows/#{workflow.id}",
               headers: agent_headers,
               as: :json
      end.to change(Workflow, :count).by(-1)
         .and change(WorkflowEnrollment, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
